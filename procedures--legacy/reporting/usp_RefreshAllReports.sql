/* ============================================================
   rpt.usp_RefreshAllReports
   Convenience wrapper the nightly batch calls to rebuild every
   reporting table for a business date in the right order. Also
   callable by hand if a report looks stale.

   Order matters a bit: daily sales + inventory snapshot are
   independent, but customer LTV is a full rebuild and is slow, so
   it runs last.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE rpt.usp_RefreshAllReports
    @BusinessDate DATE,
    @BatchId      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'rpt.usp_RefreshAllReports', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        EXEC rpt.usp_BuildDailySales        @BusinessDate = @BusinessDate, @BatchId = @BatchId;
        EXEC rpt.usp_BuildInventorySnapshot @SnapshotDate = @BusinessDate, @BatchId = @BatchId;
        EXEC rpt.usp_BuildCustomerLtv       @BatchId = @BatchId;

        EXEC util.usp_LogEnd @ProcLogId = @plog;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'rpt.usp_RefreshAllReports', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
