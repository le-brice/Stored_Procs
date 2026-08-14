/* ============================================================
   sales.usp_AddOrderLine
   Adds (or increments) a line on an open order. Resolves unit price
   via dbo.usp_GetProductPrice and tax rate via dbo.usp_GetTaxRate,
   then re-rolls totals through sales.usp_RecalcOrderTotals.

   Only allowed on NEW / CONFIRMED orders.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_AddOrderLine
    @OrderId    INT,
    @ProductId  INT,
    @Qty        INT,
    @OverridePrice DECIMAL(18,4) = NULL   -- CSR price override; bypasses lookup
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_AddOrderLine', @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        IF @Qty <= 0 THROW 52010, 'Qty must be positive', 1;

        DECLARE @status VARCHAR(20), @ccy CHAR(3), @odate DATE, @custCountry CHAR(2);
        SELECT @status = oh.Status, @ccy = oh.CurrencyCode,
               @odate = CAST(oh.OrderDate AS DATE), @custCountry = c.CountryCode
          FROM sales.OrderHeader oh
          JOIN dbo.Customer c ON c.CustomerId = oh.CustomerId
         WHERE oh.OrderId = @OrderId;

        IF @status IS NULL THROW 52011, 'Order not found', 1;
        IF @status NOT IN ('NEW','CONFIRMED') THROW 52012, 'Order not editable in current status', 1;

        DECLARE @price DECIMAL(18,4) = @OverridePrice, @catId INT, @taxRate DECIMAL(6,4);
        SELECT @catId = CategoryId FROM dbo.Product WHERE ProductId = @ProductId AND Status = 'ACTIVE';
        IF @catId IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.Product WHERE ProductId = @ProductId AND Status = 'ACTIVE')
            THROW 52013, 'Product not found or discontinued', 1;

        IF @price IS NULL
            EXEC dbo.usp_GetProductPrice @ProductId = @ProductId, @CurrencyCode = @ccy,
                 @AsOfDate = @odate, @UnitPrice = @price OUTPUT;

        IF @price IS NULL THROW 52014, 'Could not resolve price for product', 1;

        EXEC dbo.usp_GetTaxRate @CountryCode = @custCountry, @CategoryId = @catId, @TaxRate = @taxRate OUTPUT;

        -- merge into existing line for same product if present
        IF EXISTS (SELECT 1 FROM sales.OrderLine WHERE OrderId = @OrderId AND ProductId = @ProductId)
            UPDATE sales.OrderLine
               SET Qty = Qty + @Qty
             WHERE OrderId = @OrderId AND ProductId = @ProductId;
        ELSE
        BEGIN
            DECLARE @lineNo INT;
            SELECT @lineNo = ISNULL(MAX(LineNo), 0) + 1 FROM sales.OrderLine WHERE OrderId = @OrderId;
            INSERT INTO sales.OrderLine (OrderId, LineNo, ProductId, Qty, UnitPrice, TaxRate)
            VALUES (@OrderId, @lineNo, @ProductId, @Qty, @price, @taxRate);
        END

        EXEC sales.usp_RecalcOrderTotals @OrderId = @OrderId;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @Qty;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'sales.usp_AddOrderLine';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
