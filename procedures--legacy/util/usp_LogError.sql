/* ============================================================
   util.usp_LogError
   Call inside a CATCH block. Captures ERROR_* and stamps the
   ErrorLog. Does NOT rethrow -- caller decides.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE util.usp_LogError
    @ProcName SYSNAME              = NULL,
    @BatchId  UNIQUEIDENTIFIER     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO util.ErrorLog
        (BatchId, ProcName, ErrorNumber, ErrorSeverity, ErrorState,
         ErrorLine, ErrorMessage, LoggedUtc)
    VALUES
        (@BatchId,
         ISNULL(@ProcName, ERROR_PROCEDURE()),
         ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(),
         ERROR_LINE(), ERROR_MESSAGE(), SYSUTCDATETIME());
END
GO
