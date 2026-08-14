/* ============================================================
   fin.usp_PostJournalEntry
   Creates a journal entry header + lines and validates that debits
   equal credits before flipping it to POSTED. @LineSpec encoding:
       'accountCode:debit:credit, accountCode:debit:credit, ...'
   Either debit or credit should be 0 on each line.

   Returns the new JournalId. Used by the sales/returns/settlement
   journal generators.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE fin.usp_PostJournalEntry
    @EntryDate   DATE,
    @Source      VARCHAR(30),
    @Description VARCHAR(200),
    @LineSpec    VARCHAR(MAX),
    @BatchId     UNIQUEIDENTIFIER = NULL,
    @JournalId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @jno VARCHAR(20);
        EXEC util.usp_NextDocNumber @Prefix = 'JNL', @DocNumber = @jno OUTPUT;

        INSERT INTO fin.JournalEntry (JournalNo, EntryDate, Source, Description, Status, BatchId)
        VALUES (@jno, @EntryDate, @Source, @Description, 'DRAFT', @BatchId);
        SET @JournalId = SCOPE_IDENTITY();

        ;WITH raw AS (
            SELECT
                LTRIM(RTRIM(PARSENAME(REPLACE(value, ':', '.'), 3))) AS acctCode,
                TRY_CONVERT(DECIMAL(18,4), PARSENAME(REPLACE(value, ':', '.'), 2)) AS dr,
                TRY_CONVERT(DECIMAL(18,4), PARSENAME(REPLACE(value, ':', '.'), 1)) AS cr
            FROM STRING_SPLIT(@LineSpec, ',') WHERE LTRIM(RTRIM(value)) <> ''
        )
        INSERT INTO fin.JournalLine (JournalId, GLAccountId, DebitAmount, CreditAmount)
        SELECT @JournalId, ga.GLAccountId, ISNULL(r.dr,0), ISNULL(r.cr,0)
          FROM raw r JOIN fin.GLAccount ga ON ga.AccountCode = r.acctCode;

        DECLARE @dr DECIMAL(18,4), @cr DECIMAL(18,4);
        SELECT @dr = SUM(DebitAmount), @cr = SUM(CreditAmount) FROM fin.JournalLine WHERE JournalId = @JournalId;

        IF ABS(ISNULL(@dr,0) - ISNULL(@cr,0)) > 0.005
            THROW 55001, 'Journal does not balance', 1;

        UPDATE fin.JournalEntry SET Status = 'POSTED' WHERE JournalId = @JournalId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'fin.usp_PostJournalEntry', @BatchId = @BatchId;
        THROW;
    END CATCH
END
GO
