/* ============================================================
   dbo.usp_GetTaxRate
   Returns a tax rate (decimal, e.g. 0.2000 = 20%) for a country +
   category combination.

   This is a mess: most rates are hardcoded here because the
   TaxRate reference table was never built (see TAX-77, open since
   2018). Category overrides for reduced-rate goods are bolted on.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetTaxRate
    @CountryCode CHAR(2),
    @CategoryId  INT = NULL,
    @TaxRate     DECIMAL(6,4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- base rate by country (HARDCODED -- TAX-77)
    SET @TaxRate =
        CASE @CountryCode
            WHEN 'GB' THEN 0.2000
            WHEN 'IE' THEN 0.2300
            WHEN 'DE' THEN 0.1900
            WHEN 'FR' THEN 0.2000
            WHEN 'US' THEN 0.0000   -- handled at state level elsewhere... supposedly
            WHEN 'CA' THEN 0.0500
            ELSE 0.0000
        END;

    -- reduced rate categories (books=12, kids clothing=19) -- magic ids, sorry
    IF @CategoryId IN (12, 19)
        SET @TaxRate = CASE WHEN @CountryCode IN ('GB','IE') THEN 0.0000 ELSE @TaxRate END;
END
GO
