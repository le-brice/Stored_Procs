/* ============================================================
   util.usp_NextDocNumber
   Hands out the next sequential business document number for a
   given prefix (ORD, PO, RMA, JNL...). Uses a control row in
   ConfigParam keyed 'seq:<prefix>'. Serialized with an UPDLOCK.

   Format: <PREFIX>-<yyyy>-<000000>
   e.g. ORD-2026-000123
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE util.usp_NextDocNumber
    @Prefix    VARCHAR(10),
    @DocNumber VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @key VARCHAR(100) = 'seq:' + @Prefix;
    DECLARE @next INT;
    DECLARE @yr CHAR(4) = CONVERT(CHAR(4), YEAR(SYSUTCDATETIME()));

    BEGIN TRAN;

        -- ensure the row exists
        IF NOT EXISTS (SELECT 1 FROM util.ConfigParam WITH (UPDLOCK, HOLDLOCK) WHERE ParamKey = @key)
            INSERT INTO util.ConfigParam (ParamKey, ParamValue, ParamType, Description)
            VALUES (@key, '0', 'int', 'sequence counter for ' + @Prefix);

        UPDATE util.ConfigParam WITH (UPDLOCK)
           SET @next = ParamValue = CAST(ParamValue AS INT) + 1,
               ModifiedUtc = SYSUTCDATETIME()
         WHERE ParamKey = @key;

    COMMIT;

    SET @DocNumber = @Prefix + '-' + @yr + '-' + RIGHT('000000' + CAST(@next AS VARCHAR(10)), 6);
END
GO
