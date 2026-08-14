/* ============================================================
   fin.usp_ReverseJournal
   Posts a mirror-image journal that reverses a previously POSTED
   entry (swaps debits/credits) and marks the original REVERSED.
   Used when a daily journal was generated against bad data and
   needs backing out before re-running the generator.

   Will not reverse an already-reversed or draft entry.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE fin.usp_ReverseJournal
    @JournalId INT,
    @NewJournalId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @status VARCHAR(20), @date DATE, @desc VARCHAR(200);
        SELECT @status = Status, @date = EntryDate, @desc = Description
          FROM fin.JournalEntry WHERE JournalId = @JournalId;

        IF @status IS NULL THROW 55010, 'Journal not found', 1;
        IF @status <> 'POSTED' THROW 55011, 'Only POSTED journals can be reversed', 1;

        DECLARE @jno VARCHAR(20);
        EXEC util.usp_NextDocNumber @Prefix = 'JNL', @DocNumber = @jno OUTPUT;

        INSERT INTO fin.JournalEntry (JournalNo, EntryDate, Source, Description, Status)
        VALUES (@jno, @date, 'MANUAL', CONCAT('REVERSAL of ', @JournalId, ': ', @desc), 'POSTED');
        SET @NewJournalId = SCOPE_IDENTITY();

        -- swap dr/cr
        INSERT INTO fin.JournalLine (JournalId, GLAccountId, DebitAmount, CreditAmount, Memo)
        SELECT @NewJournalId, GLAccountId, CreditAmount, DebitAmount, 'reversal'
          FROM fin.JournalLine WHERE JournalId = @JournalId;

        UPDATE fin.JournalEntry SET Status = 'REVERSED' WHERE JournalId = @JournalId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'fin.usp_ReverseJournal';
        THROW;
    END CATCH
END
GO
