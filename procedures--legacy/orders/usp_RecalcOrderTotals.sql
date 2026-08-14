/* ============================================================
   sales.usp_RecalcOrderTotals
   Recomputes line totals and rolls them up to the header.
   This is the "current" one. Tax is computed per line from the
   line's TaxRate (set when the line was added). Header discount is
   applied AFTER subtotal, BEFORE tax-on-discounted? -- no. Tax is
   on the gross line, discount reduces grand total only. (yes this
   is arguably wrong for VAT but finance signed off, see SALES-412.)

   See also sales.usp_RecalculateOrderTotals_v2 -- DO NOT call both.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_RecalcOrderTotals
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- per-line recompute
    UPDATE ol
       SET LineTax   = ROUND((ol.UnitPrice * ol.Qty - ol.LineDiscount) * ol.TaxRate, 4),
           LineTotal = ROUND((ol.UnitPrice * ol.Qty - ol.LineDiscount)
                             + ((ol.UnitPrice * ol.Qty - ol.LineDiscount) * ol.TaxRate), 4)
      FROM sales.OrderLine ol
     WHERE ol.OrderId = @OrderId;

    DECLARE @sub DECIMAL(18,4), @tax DECIMAL(18,4), @lineDisc DECIMAL(18,4);

    SELECT @sub      = ISNULL(SUM(UnitPrice * Qty), 0),
           @lineDisc = ISNULL(SUM(LineDiscount), 0),
           @tax      = ISNULL(SUM(LineTax), 0)
      FROM sales.OrderLine
     WHERE OrderId = @OrderId;

    DECLARE @hdrDisc DECIMAL(18,4), @ship DECIMAL(18,4);
    SELECT @hdrDisc = DiscountTotal, @ship = ShippingTotal
      FROM sales.OrderHeader WHERE OrderId = @OrderId;

    UPDATE sales.OrderHeader
       SET SubTotal   = @sub,
           TaxTotal   = @tax,
           GrandTotal = @sub - @lineDisc - @hdrDisc + @tax + ISNULL(@ship,0),
           ModifiedUtc = SYSUTCDATETIME()
     WHERE OrderId = @OrderId;
END
GO
