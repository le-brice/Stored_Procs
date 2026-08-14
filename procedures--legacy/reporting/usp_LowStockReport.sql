/* ============================================================
   rpt.usp_LowStockReport
   Returns products below reorder for a warehouse, joined to the
   supplier + open PO coverage, so purchasing can see what's already
   on the way. Reads from the latest rpt.InventorySnapshot if one
   exists for today, else live inv.StockLevel.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE rpt.usp_LowStockReport
    @WarehouseId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @defPoint INT = 10;   -- (again. RunReorder, BuildInventorySnapshot, here.)

    IF EXISTS (SELECT 1 FROM rpt.InventorySnapshot WHERE SnapshotDate = @today)
        SELECT s.WarehouseId, s.ProductId, p.Sku, p.ProductName, sup.SupplierName,
               s.QtyAvailable,
               (SELECT ISNULL(SUM(pol.QtyOrdered - pol.QtyReceived),0)
                  FROM inv.PurchaseOrderLine pol
                  JOIN inv.PurchaseOrder po ON po.PurchaseOrderId = pol.PurchaseOrderId
                 WHERE po.WarehouseId = s.WarehouseId AND pol.ProductId = s.ProductId
                   AND po.Status IN ('SENT','PARTIAL','DRAFT')) AS OnOrder
          FROM rpt.InventorySnapshot s
          JOIN dbo.Product p ON p.ProductId = s.ProductId
          LEFT JOIN dbo.Supplier sup ON sup.SupplierId = p.SupplierId
         WHERE s.SnapshotDate = @today AND s.BelowReorder = 1
           AND (@WarehouseId IS NULL OR s.WarehouseId = @WarehouseId)
         ORDER BY s.QtyAvailable;
    ELSE
        SELECT sl.WarehouseId, sl.ProductId, p.Sku, p.ProductName, sup.SupplierName,
               (sl.QtyOnHand - sl.QtyAllocated) AS QtyAvailable,
               sl.QtyOnOrder AS OnOrder
          FROM inv.StockLevel sl
          JOIN dbo.Product p ON p.ProductId = sl.ProductId
          LEFT JOIN dbo.Supplier sup ON sup.SupplierId = p.SupplierId
         WHERE (sl.QtyOnHand - sl.QtyAllocated + sl.QtyOnOrder) <= ISNULL(sl.ReorderPoint, @defPoint)
           AND (@WarehouseId IS NULL OR sl.WarehouseId = @WarehouseId)
         ORDER BY QtyAvailable;
END
GO
