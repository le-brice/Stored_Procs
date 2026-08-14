/* ============================================================
   rpt.usp_BuildInventorySnapshot
   Point-in-time snapshot of stock for a date across all warehouses.
   StockValue = QtyOnHand * Product.UnitCost. BelowReorder flags
   items at/under their reorder point (same fallback logic as
   inv.usp_RunReorder -- copy/pasted, naturally, so if you change
   the default there change it here too).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE rpt.usp_BuildInventorySnapshot
    @SnapshotDate DATE = NULL,
    @BatchId      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @SnapshotDate IS NULL SET @SnapshotDate = CAST(SYSUTCDATETIME() AS DATE);

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'rpt.usp_BuildInventorySnapshot', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- NOTE: default reorder point hardcoded 10 here too (see RunReorder)
        DECLARE @defPoint INT = 10;

        DELETE FROM rpt.InventorySnapshot WHERE SnapshotDate = @SnapshotDate;

        INSERT INTO rpt.InventorySnapshot
            (SnapshotDate, WarehouseId, ProductId, QtyOnHand, QtyAllocated,
             QtyAvailable, StockValue, BelowReorder)
        SELECT
            @SnapshotDate,
            sl.WarehouseId,
            sl.ProductId,
            sl.QtyOnHand,
            sl.QtyAllocated,
            sl.QtyOnHand - sl.QtyAllocated,
            ROUND(sl.QtyOnHand * ISNULL(p.UnitCost, 0), 4),
            CASE WHEN (sl.QtyOnHand - sl.QtyAllocated + sl.QtyOnOrder) <= ISNULL(sl.ReorderPoint, @defPoint) THEN 1 ELSE 0 END
        FROM inv.StockLevel sl
        JOIN dbo.Product p ON p.ProductId = sl.ProductId;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @@ROWCOUNT;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'rpt.usp_BuildInventorySnapshot', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
