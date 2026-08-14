/* ============================================================
   etl.usp_LoadFxRates
   Promotes stg.RawFxRate -> ref.FxRate. Parses text date + rate.

   !!! THE FLAKY ONE (see README) !!!
   If there are NO unprocessed staging rows it SILENTLY returns
   success (logs 'no rates') rather than erroring. So when the
   upstream feed is late, the nightly batch happily runs on
   yesterday's rates and finance reports drift. There's a long
   argument in FX-19 about whether this should hard-fail. It still
   doesn't.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_LoadFxRates
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_LoadFxRates', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM stg.RawFxRate WHERE IsProcessed = 0)
        BEGIN
            -- silent no-op (FX-19). do NOT change without telling finance.
            EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = 'no rates (feed late?)';
            RETURN 0;
        END

        MERGE ref.FxRate AS tgt
        USING (
            SELECT FromCurrency, ToCurrency,
                   TRY_CONVERT(DATE, RateDateText) AS RateDate,
                   TRY_CONVERT(DECIMAL(18,8), RateText) AS Rate
              FROM stg.RawFxRate
             WHERE IsProcessed = 0
               AND TRY_CONVERT(DATE, RateDateText) IS NOT NULL
               AND TRY_CONVERT(DECIMAL(18,8), RateText) IS NOT NULL
        ) AS src
        ON tgt.FromCurrency = src.FromCurrency AND tgt.ToCurrency = src.ToCurrency AND tgt.RateDate = src.RateDate
        WHEN MATCHED THEN UPDATE SET Rate = src.Rate, LoadedUtc = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (FromCurrency, ToCurrency, RateDate, Rate)
             VALUES (src.FromCurrency, src.ToCurrency, src.RateDate, src.Rate);

        UPDATE stg.RawFxRate SET IsProcessed = 1 WHERE IsProcessed = 0;

        EXEC util.usp_LogEnd @ProcLogId = @plog;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'etl.usp_LoadFxRates', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
