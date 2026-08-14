/* ============================================================
   rpt.usp_BuildCustomerLtv
   Full rebuild of rpt.CustomerLtv across all active customers.
   Net spend uses GrandTotal of non-cancelled orders converted to
   USD (calls dbo.usp_ConvertCurrency per order -- slow, runs in the
   nightly batch only).

   Segment + LtvScore logic. NOTE the GOLD/loyalty threshold here is
   12000 lifetime spend-equiv, which does NOT match the loyalty tier
   thresholds in dbo.usp_RecalcLoyaltyTier (10000 points). Different
   units, but people assume they line up. They don't. LOYALTY-44.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE rpt.usp_BuildCustomerLtv
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'rpt.usp_BuildCustomerLtv', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#spend') IS NOT NULL DROP TABLE #spend;
        CREATE TABLE #spend (CustomerId INT, OrderId INT, OrderDate DATE, GrandUsd DECIMAL(18,4));

        DECLARE @cid INT, @oid INT, @odate DATE, @ccy CHAR(3), @grand DECIMAL(18,4), @usd DECIMAL(18,4);
        DECLARE c_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT CustomerId, OrderId, CAST(OrderDate AS DATE), CurrencyCode, GrandTotal
              FROM sales.OrderHeader WHERE Status NOT IN ('CANCELLED','NEW');
        OPEN c_cur;
        FETCH NEXT FROM c_cur INTO @cid, @oid, @odate, @ccy, @grand;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ConvertCurrency @Amount=@grand, @FromCurrency=@ccy, @ToCurrency='USD', @AsOfDate=@odate, @Result=@usd OUTPUT;
            INSERT INTO #spend VALUES (@cid, @oid, @odate, @usd);
            FETCH NEXT FROM c_cur INTO @cid, @oid, @odate, @ccy, @grand;
        END
        CLOSE c_cur; DEALLOCATE c_cur;

        DELETE FROM rpt.CustomerLtv;

        ;WITH agg AS (
            SELECT CustomerId,
                   MIN(OrderDate) AS FirstOrderDate,
                   MAX(OrderDate) AS LastOrderDate,
                   COUNT(*) AS OrderCount,
                   SUM(GrandUsd) AS TotalNetSpend
              FROM #spend GROUP BY CustomerId
        )
        INSERT INTO rpt.CustomerLtv
            (CustomerId, FirstOrderDate, LastOrderDate, OrderCount, TotalNetSpend,
             AvgOrderValue, LtvScore, Segment)
        SELECT
            a.CustomerId, a.FirstOrderDate, a.LastOrderDate, a.OrderCount, a.TotalNetSpend,
            CASE WHEN a.OrderCount = 0 THEN 0 ELSE a.TotalNetSpend / a.OrderCount END,
            -- crude score: spend weighted by recency (penalise lapsed)
            ROUND(a.TotalNetSpend
                  * CASE WHEN DATEDIFF(DAY, a.LastOrderDate, SYSUTCDATETIME()) > 365 THEN 0.5 ELSE 1.0 END, 2),
            CASE
                WHEN a.TotalNetSpend >= 12000 THEN 'VIP'
                WHEN DATEDIFF(DAY, a.LastOrderDate, SYSUTCDATETIME()) > 365 THEN 'LAPSED'
                WHEN a.OrderCount = 1 THEN 'NEW'
                ELSE 'REGULAR'
            END
        FROM agg a;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @@ROWCOUNT;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','c_cur') >= 0 BEGIN CLOSE c_cur; DEALLOCATE c_cur; END
        EXEC util.usp_LogError @ProcName = 'rpt.usp_BuildCustomerLtv', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
