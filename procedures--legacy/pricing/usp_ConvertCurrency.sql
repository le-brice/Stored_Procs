/* ============================================================
   dbo.usp_ConvertCurrency
   Converts an amount between currencies using ref.FxRate for the
   given date (falls back to most recent rate on/before the date).
   Identity conversion (same currency) returns the input.

   Returns the converted amount via @Result OUTPUT.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ConvertCurrency
    @Amount       DECIMAL(18,4),
    @FromCurrency CHAR(3),
    @ToCurrency   CHAR(3),
    @AsOfDate     DATE = NULL,
    @Result       DECIMAL(18,4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOfDate IS NULL SET @AsOfDate = CAST(SYSUTCDATETIME() AS DATE);

    IF @FromCurrency = @ToCurrency
    BEGIN
        SET @Result = @Amount;
        RETURN 0;
    END

    DECLARE @rate DECIMAL(18,8);

    SELECT TOP (1) @rate = Rate
      FROM ref.FxRate
     WHERE FromCurrency = @FromCurrency
       AND ToCurrency   = @ToCurrency
       AND RateDate     <= @AsOfDate
     ORDER BY RateDate DESC;

    -- try the inverse if direct pair missing
    IF @rate IS NULL
    BEGIN
        SELECT TOP (1) @rate = 1.0 / NULLIF(Rate, 0)
          FROM ref.FxRate
         WHERE FromCurrency = @ToCurrency
           AND ToCurrency   = @FromCurrency
           AND RateDate     <= @AsOfDate
         ORDER BY RateDate DESC;
    END

    IF @rate IS NULL
    BEGIN
        -- no rate found; caller probably won't check this. historically we
        -- just passed the amount through 1:1 rather than erroring. keep that.
        SET @Result = @Amount;
        RETURN 1;
    END

    SET @Result = ROUND(@Amount * @rate, 4);
    RETURN 0;
END
GO
