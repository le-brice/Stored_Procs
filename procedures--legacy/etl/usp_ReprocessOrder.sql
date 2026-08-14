/* ============================================================
   etl.usp_ReprocessOrder
   Recomputes totals for a single historical order. Used when a tax
   rate or price was corrected retroactively and an order needs its
   numbers refreshed without re-importing.

   !!! GOTCHA: for orders created before 2020-01-01 this calls the
   OLD sales.usp_RecalculateOrderTotals_v2 (because that's how those
   orders were originally totalled and we want to keep them
   internally consistent). For everything else it calls the current
   sales.usp_RecalcOrderTotals. So the SAME proc gives DIFFERENT tax
   treatment depending on order age. This is intentional and also
   the source of endless confusion. SALES-412 / FIN-301. !!!
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_ReprocessOrder
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @createdDate DATE;
    SELECT @createdDate = CAST(CreatedUtc AS DATE) FROM sales.OrderHeader WHERE OrderId = @OrderId;
    IF @createdDate IS NULL THROW 56001, 'Order not found', 1;

    DECLARE @cutoff DATE = '2020-01-01';

    IF @createdDate < @cutoff
        EXEC sales.usp_RecalculateOrderTotals_v2 @OrderId = @OrderId, @ApportionHeaderDiscount = 1;
    ELSE
        EXEC sales.usp_RecalcOrderTotals @OrderId = @OrderId;
END
GO
