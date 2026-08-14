/* ============================================================
   util.usp_GetConfig
   Returns a config value from util.ConfigParam via OUTPUT param.
   Falls back to @Default if the key is missing.

   WARNING: a few procs read ConfigParam directly with their own
   SELECT instead of calling this. If you change behaviour here,
   grep for 'ConfigParam' to find the stragglers.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE util.usp_GetConfig
    @ParamKey VARCHAR(100),
    @Default  VARCHAR(400) = NULL,
    @Value    VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @Value = ParamValue
      FROM util.ConfigParam
     WHERE ParamKey = @ParamKey;

    IF @Value IS NULL
        SET @Value = @Default;
END
GO
