/* ============================================================
   fin.usp_GenerateSalesJournal
   Builds the daily sales journal for a business date: sums net
   revenue, tax collected, and the cost of goods shipped that day,
   and posts a balanced entry via fin.usp_PostJournalEntry.

   Accounting (simplified, agreed with FIN 2017):
     DR  1200 Accounts Receivable   (grand total of orders)
       CR 4000 Sales Revenue        (net of tax)
       CR 2200 Sales Tax Payable    (tax)
     DR  5000 COGS                  (cost of goods shipped)
       CR 1300 Inventory            (cost of goods shipped)

   COGS pulled from inv.StockMovement SHIP rows for the date. All in
   reporting currency (USD); multi-currency orders converted via
   dbo.usp_ConvertCurrency. (FX rounding lands in a suspense
   account 9999, see FIN-260 -- usually pennies.)
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE fin.usp_GenerateSalesJournal
    @BusinessDate DATE,
    @BatchId      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'fin.usp_GenerateSalesJournal', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- revenue side: orders that reached PAID+ on this date.
        -- convert each order's totals to USD.
        IF OBJECT_ID('tempdb..#rev') IS NOT NULL DROP TABLE #rev;
        CREATE TABLE #rev (OrderId INT, NetUsd DECIMAL(18,4), TaxUsd DECIMAL(18,4), GrandUsd DECIMAL(18,4));

        DECLARE @oid INT, @ccy CHAR(3), @net DECIMAL(18,4), @tax DECIMAL(18,4), @grand DECIMAL(18,4);
        DECLARE ord_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT OrderId, CurrencyCode, (SubTotal - DiscountTotal), TaxTotal, GrandTotal
              FROM sales.OrderHeader
             WHERE CAST(ModifiedUtc AS DATE) = @BusinessDate
               AND Status IN ('PAID','SHIPPED','COMPLETED');
        OPEN ord_cur;
        FETCH NEXT FROM ord_cur INTO @oid, @ccy, @net, @tax, @grand;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @netU DECIMAL(18,4), @taxU DECIMAL(18,4), @grU DECIMAL(18,4);
            EXEC dbo.usp_ConvertCurrency @Amount=@net,  @FromCurrency=@ccy, @ToCurrency='USD', @AsOfDate=@BusinessDate, @Result=@netU OUTPUT;
            EXEC dbo.usp_ConvertCurrency @Amount=@tax,  @FromCurrency=@ccy, @ToCurrency='USD', @AsOfDate=@BusinessDate, @Result=@taxU OUTPUT;
            EXEC dbo.usp_ConvertCurrency @Amount=@grand,@FromCurrency=@ccy, @ToCurrency='USD', @AsOfDate=@BusinessDate, @Result=@grU OUTPUT;
            INSERT INTO #rev VALUES (@oid, @netU, @taxU, @grU);
            FETCH NEXT FROM ord_cur INTO @oid, @ccy, @net, @tax, @grand;
        END
        CLOSE ord_cur; DEALLOCATE ord_cur;

        DECLARE @totalNet DECIMAL(18,4), @totalTax DECIMAL(18,4), @totalGrand DECIMAL(18,4);
        SELECT @totalNet = ISNULL(SUM(NetUsd),0), @totalTax = ISNULL(SUM(TaxUsd),0), @totalGrand = ISNULL(SUM(GrandUsd),0) FROM #rev;

        -- COGS from SHIP movements on the date (Qty stored negative)
        DECLARE @cogs DECIMAL(18,4);
        SELECT @cogs = ISNULL(SUM(ABS(Qty) * ISNULL(UnitCost,0)), 0)
          FROM inv.StockMovement
         WHERE MovementType = 'SHIP' AND CAST(CreatedUtc AS DATE) = @BusinessDate;

        IF @totalGrand = 0 AND @cogs = 0
        BEGIN
            EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = 'no activity';
            RETURN 0;
        END

        -- balance the AR side: rounding plug into 9999
        DECLARE @arPlug DECIMAL(18,4) = @totalGrand - (@totalNet + @totalTax);

        DECLARE @spec VARCHAR(MAX) =
            CONCAT('1200:', @totalGrand, ':0',
                   ',4000:0:', @totalNet,
                   ',2200:0:', @totalTax,
                   ',9999:', CASE WHEN @arPlug < 0 THEN ABS(@arPlug) ELSE 0 END, ':', CASE WHEN @arPlug > 0 THEN @arPlug ELSE 0 END,
                   ',5000:', @cogs, ':0',
                   ',1300:0:', @cogs);

        DECLARE @jid INT;
        EXEC fin.usp_PostJournalEntry
             @EntryDate = @BusinessDate, @Source = 'SALES',
             @Description = 'Daily sales', @LineSpec = @spec, @BatchId = @BatchId, @JournalId = @jid OUTPUT;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = CONCAT('journal ', @jid);
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ord_cur') >= 0 BEGIN CLOSE ord_cur; DEALLOCATE ord_cur; END
        EXEC util.usp_LogError @ProcName = 'fin.usp_GenerateSalesJournal', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
