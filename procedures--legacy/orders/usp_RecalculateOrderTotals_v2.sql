/* ============================================================
   sales.usp_RecalculateOrderTotals_v2
   !!! LEGACY / SUSPECT -- see SALES-412 !!!

   This was the 2018 rewrite that was supposed to replace
   sales.usp_RecalcOrderTotals. It computes tax on the DISCOUNTED
   subtotal (header discount apportioned across lines) which gives
   different numbers. It is STILL referenced by:
       - etl.usp_ReprocessOrder  (historical reprocessing)
       - rpt.usp_BuildDailySales (NO -- it doesn't, double check)
   Some orders in 2018-2019 were totalled with this. Do not "fix"
   without checking which orders were created when.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_RecalculateOrderTotals_v2
    @OrderId INT,
    @ApportionHeaderDiscount BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sub DECIMAL(18,4), @hdrDisc DECIMAL(18,4), @ship DECIMAL(18,4);

    SELECT @sub = ISNULL(SUM(UnitPrice * Qty), 0)
      FROM sales.OrderLine WHERE OrderId = @OrderId;

    SELECT @hdrDisc = DiscountTotal, @ship = ShippingTotal
      FROM sales.OrderHeader WHERE OrderId = @OrderId;

    IF @sub = 0 SET @sub = 1;  -- avoid div/0; harmless because no lines anyway

    -- apportion header discount proportionally, then tax the net line
    UPDATE ol
       SET LineDiscount = ol.LineDiscount
            + CASE WHEN @ApportionHeaderDiscount = 1
                   THEN ROUND(@hdrDisc * (ol.UnitPrice * ol.Qty) / @sub, 4)
                   ELSE 0 END
      FROM sales.OrderLine ol
     WHERE ol.OrderId = @OrderId;

    UPDATE ol
       SET LineTax   = ROUND((ol.UnitPrice * ol.Qty - ol.LineDiscount) * ol.TaxRate, 4),
           LineTotal = ROUND((ol.UnitPrice * ol.Qty - ol.LineDiscount)
                             * (1 + ol.TaxRate), 4)
      FROM sales.OrderLine ol
     WHERE ol.OrderId = @OrderId;

    DECLARE @net DECIMAL(18,4), @tax DECIMAL(18,4);
    SELECT @net = ISNULL(SUM(UnitPrice * Qty - LineDiscount), 0),
           @tax = ISNULL(SUM(LineTax), 0)
      FROM sales.OrderLine WHERE OrderId = @OrderId;

    UPDATE sales.OrderHeader
       SET SubTotal   = @net,
           TaxTotal   = @tax,
           GrandTotal = @net + @tax + ISNULL(@ship, 0),
           ModifiedUtc = SYSUTCDATETIME()
     WHERE OrderId = @OrderId;
END
GO
