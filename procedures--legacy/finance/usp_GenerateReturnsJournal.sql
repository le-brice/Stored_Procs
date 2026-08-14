/* ============================================================
   fin.usp_GenerateReturnsJournal
   Mirror of the sales journal for refunds/returns booked on a date.

     DR 4000 Sales Revenue (contra)   (net refunded)
     DR 2200 Sales Tax Payable        (tax refunded)
       CR 1200 Accounts Receivable    (gross refund)
     DR 1300 Inventory                (cost of restocked goods)
       CR 5000 COGS                   (cost of restocked goods)

   Restock cost comes from RETURN stock movements on the date.
   Returns are assumed in the order currency -> convert to USD.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE fin.usp_GenerateReturnsJournal
    @BusinessDate DATE,
    @BatchId      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'fin.usp_GenerateReturnsJournal', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- gross refund (in USD) + a rough tax split using the order's blended rate
        DECLARE @gross DECIMAL(18,4) = 0, @tax DECIMAL(18,4) = 0;

        DECLARE @rid INT, @oid INT, @refund DECIMAL(18,4), @ccy CHAR(3), @ordTax DECIMAL(18,4), @ordGrand DECIMAL(18,4);
        DECLARE ret_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT rh.ReturnId, rh.OrderId, rh.RefundAmount, oh.CurrencyCode, oh.TaxTotal, oh.GrandTotal
              FROM sales.ReturnHeader rh
              JOIN sales.OrderHeader oh ON oh.OrderId = rh.OrderId
             WHERE CAST(rh.CreatedUtc AS DATE) = @BusinessDate AND rh.Status = 'REFUNDED';
        OPEN ret_cur;
        FETCH NEXT FROM ret_cur INTO @rid, @oid, @refund, @ccy, @ordTax, @ordGrand;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @refUsd DECIMAL(18,4);
            EXEC dbo.usp_ConvertCurrency @Amount=@refund, @FromCurrency=@ccy, @ToCurrency='USD', @AsOfDate=@BusinessDate, @Result=@refUsd OUTPUT;
            DECLARE @taxFactor DECIMAL(18,6) = CASE WHEN @ordGrand = 0 THEN 0 ELSE @ordTax/@ordGrand END;
            SET @gross = @gross + @refUsd;
            SET @tax   = @tax + ROUND(@refUsd * @taxFactor, 4);
            FETCH NEXT FROM ret_cur INTO @rid, @oid, @refund, @ccy, @ordTax, @ordGrand;
        END
        CLOSE ret_cur; DEALLOCATE ret_cur;

        DECLARE @net DECIMAL(18,4) = @gross - @tax;

        DECLARE @restockCost DECIMAL(18,4);
        SELECT @restockCost = ISNULL(SUM(ABS(Qty) * ISNULL(UnitCost,0)), 0)
          FROM inv.StockMovement
         WHERE MovementType = 'RETURN' AND CAST(CreatedUtc AS DATE) = @BusinessDate;

        IF @gross = 0 AND @restockCost = 0
        BEGIN
            EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = 'no returns';
            RETURN 0;
        END

        DECLARE @spec VARCHAR(MAX) =
            CONCAT('4000:', @net, ':0',
                   ',2200:', @tax, ':0',
                   ',1200:0:', @gross,
                   ',1300:', @restockCost, ':0',
                   ',5000:0:', @restockCost);

        DECLARE @jid INT;
        EXEC fin.usp_PostJournalEntry
             @EntryDate = @BusinessDate, @Source = 'RETURNS',
             @Description = 'Daily returns', @LineSpec = @spec, @BatchId = @BatchId, @JournalId = @jid OUTPUT;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = CONCAT('journal ', @jid);
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ret_cur') >= 0 BEGIN CLOSE ret_cur; DEALLOCATE ret_cur; END
        EXEC util.usp_LogError @ProcName = 'fin.usp_GenerateReturnsJournal', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
