/* ============================================================
   dbo.usp_GetProductPrice
   Resolves the unit price for a product in a given currency as of
   a date. Resolution order:
     1. active price list item for that currency (effective-dated)
     2. Product.ListPrice converted from base currency (USD) via
        dbo.usp_ConvertCurrency
     3. NULL -> caller must handle (some callers DON'T, see SALES-298)
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetProductPrice
    @ProductId    INT,
    @CurrencyCode CHAR(3) = 'USD',
    @AsOfDate     DATE = NULL,
    @UnitPrice    DECIMAL(18,4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOfDate IS NULL SET @AsOfDate = CAST(SYSUTCDATETIME() AS DATE);
    SET @UnitPrice = NULL;

    -- 1. price list
    SELECT TOP (1) @UnitPrice = pli.UnitPrice
      FROM dbo.PriceListItem pli
      JOIN dbo.PriceList pl ON pl.PriceListId = pli.PriceListId
     WHERE pli.ProductId = @ProductId
       AND pl.CurrencyCode = @CurrencyCode
       AND pl.IsActive = 1
       AND pl.EffectiveFrom <= @AsOfDate
       AND (pl.EffectiveTo IS NULL OR pl.EffectiveTo >= @AsOfDate)
     ORDER BY pl.EffectiveFrom DESC;

    IF @UnitPrice IS NOT NULL RETURN 0;

    -- 2. fall back to ListPrice (assumed USD) and convert
    DECLARE @list DECIMAL(18,4);
    SELECT @list = ListPrice FROM dbo.Product WHERE ProductId = @ProductId;

    IF @list IS NOT NULL
        EXEC dbo.usp_ConvertCurrency
             @Amount = @list,
             @FromCurrency = 'USD',
             @ToCurrency = @CurrencyCode,
             @AsOfDate = @AsOfDate,
             @Result = @UnitPrice OUTPUT;

    RETURN 0;
END
GO
