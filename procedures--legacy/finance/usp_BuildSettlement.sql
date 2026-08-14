/* ============================================================
   fin.usp_BuildSettlement
   Aggregates captured (and refunded) payments for a date by payment
   method into fin.Settlement rows, applying a processor fee % per
   method from config keys 'settlement.fee.<METHOD>' (e.g.
   settlement.fee.CARD = '0.029'). Net = gross - fee.

   These rows are what fin.usp_ReconcileSettlements later compares
   against expected sales.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE fin.usp_BuildSettlement
    @SettlementDate DATE,
    @BatchId        UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'fin.usp_BuildSettlement', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- wipe any prior build for the date (idempotent re-run)
        DELETE FROM fin.Settlement WHERE SettlementDate = @SettlementDate AND Status = 'OPEN';

        IF OBJECT_ID('tempdb..#gross') IS NOT NULL DROP TABLE #gross;
        SELECT PaymentMethod, SUM(Amount) AS GrossAmount
          INTO #gross
          FROM sales.Payment
         WHERE CAST(ProcessedUtc AS DATE) = @SettlementDate
           AND Status IN ('CAPTURED','REFUNDED')
         GROUP BY PaymentMethod;

        DECLARE @method VARCHAR(20), @gross DECIMAL(18,4), @feeTxt VARCHAR(400), @feePct DECIMAL(18,6), @fee DECIMAL(18,4);
        DECLARE m_cur CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentMethod, GrossAmount FROM #gross;
        OPEN m_cur;
        FETCH NEXT FROM m_cur INTO @method, @gross;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC util.usp_GetConfig @ParamKey = CONCAT('settlement.fee.', @method), @Default = '0', @Value = @feeTxt OUTPUT;
            SET @feePct = ISNULL(TRY_CONVERT(DECIMAL(18,6), @feeTxt), 0);
            SET @fee = ROUND(@gross * @feePct, 4);

            INSERT INTO fin.Settlement (SettlementDate, PaymentMethod, GrossAmount, FeeAmount, NetAmount, Status)
            VALUES (@SettlementDate, @method, @gross, @fee, @gross - @fee, 'OPEN');

            FETCH NEXT FROM m_cur INTO @method, @gross;
        END
        CLOSE m_cur; DEALLOCATE m_cur;

        EXEC util.usp_LogEnd @ProcLogId = @plog;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','m_cur') >= 0 BEGIN CLOSE m_cur; DEALLOCATE m_cur; END
        EXEC util.usp_LogError @ProcName = 'fin.usp_BuildSettlement', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
