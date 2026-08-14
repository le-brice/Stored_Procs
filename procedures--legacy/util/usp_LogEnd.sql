/* ============================================================
   util.usp_LogEnd
   Closes out a ProcLog row. Status defaults to SUCCESS.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE util.usp_LogEnd
    @ProcLogId    BIGINT,
    @Status       VARCHAR(20)   = 'SUCCESS',
    @RowsAffected BIGINT        = NULL,
    @Message      VARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE util.ProcLog
       SET Status       = @Status,
           RowsAffected = @RowsAffected,
           Message      = @Message,
           EndedUtc     = SYSUTCDATETIME()
     WHERE ProcLogId    = @ProcLogId;
END
GO
