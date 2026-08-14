/* ============================================================
   util.usp_LogStart
   Writes a STARTED row to util.ProcLog and returns its id via
   @ProcLogId OUTPUT. Pretty much every proc calls this first.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE util.usp_LogStart
    @ProcName   SYSNAME,
    @BatchId    UNIQUEIDENTIFIER = NULL,
    @ProcLogId  BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO util.ProcLog (BatchId, ProcName, Status, StartedUtc)
    VALUES (@BatchId, @ProcName, 'STARTED', SYSUTCDATETIME());

    SET @ProcLogId = SCOPE_IDENTITY();
END
GO
