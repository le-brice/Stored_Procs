/* ============================================================
   inv.usp_RunReorder
   Scans stock levels for a warehouse, finds products at/below their
   reorder point (after accounting for QtyOnOrder), groups the
   needed quantities by supplier, and raises a draft PO per supplier
   via inv.usp_CreatePurchaseOrder.

   Reorder point/qty resolution (this is the messy bit):
     - StockLevel.ReorderPoint / ReorderQty if set
     - else config 'reorder.default.point' / 'reorder.default.qty'
     - else hardcoded 10 / 50 (yes, also lives in the README TODO)
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_RunReorder
    @WarehouseId INT,
    @WhatIf      BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'inv.usp_RunReorder', @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        DECLARE @defPointTxt VARCHAR(400), @defQtyTxt VARCHAR(400);
        EXEC util.usp_GetConfig @ParamKey = 'reorder.default.point', @Default = '10', @Value = @defPointTxt OUTPUT;
        EXEC util.usp_GetConfig @ParamKey = 'reorder.default.qty',   @Default = '50', @Value = @defQtyTxt OUTPUT;
        DECLARE @defPoint INT = TRY_CONVERT(INT, @defPointTxt), @defQty INT = TRY_CONVERT(INT, @defQtyTxt);
        IF @defPoint IS NULL SET @defPoint = 10;
        IF @defQty   IS NULL SET @defQty = 50;

        IF OBJECT_ID('tempdb..#needed') IS NOT NULL DROP TABLE #needed;

        SELECT sl.ProductId,
               p.SupplierId,
               ISNULL(sl.ReorderQty, @defQty) AS OrderQty,
               p.UnitCost
          INTO #needed
          FROM inv.StockLevel sl
          JOIN dbo.Product p ON p.ProductId = sl.ProductId AND p.Status = 'ACTIVE'
         WHERE sl.WarehouseId = @WarehouseId
           AND (sl.QtyOnHand - sl.QtyAllocated + sl.QtyOnOrder) <= ISNULL(sl.ReorderPoint, @defPoint)
           AND p.SupplierId IS NOT NULL;

        IF @WhatIf = 1
        BEGIN
            SELECT * FROM #needed ORDER BY SupplierId, ProductId;
            EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = 'WHATIF';
            RETURN 0;
        END

        -- one PO per supplier
        DECLARE @sup INT, @spec VARCHAR(MAX), @poId INT, @poNo VARCHAR(20), @poCount INT = 0;
        DECLARE sup_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT SupplierId FROM #needed;
        OPEN sup_cur;
        FETCH NEXT FROM sup_cur INTO @sup;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @spec = STUFF((
                SELECT ',' + CAST(ProductId AS VARCHAR(12)) + ':' + CAST(OrderQty AS VARCHAR(12))
                       + ':' + CAST(ISNULL(UnitCost,0) AS VARCHAR(20))
                  FROM #needed WHERE SupplierId = @sup
                  FOR XML PATH('')), 1, 1, '');

            EXEC inv.usp_CreatePurchaseOrder
                 @SupplierId = @sup, @WarehouseId = @WarehouseId, @LineSpec = @spec,
                 @PurchaseOrderId = @poId OUTPUT, @PoNumber = @poNo OUTPUT;
            SET @poCount = @poCount + 1;

            FETCH NEXT FROM sup_cur INTO @sup;
        END
        CLOSE sup_cur; DEALLOCATE sup_cur;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @poCount, @Message = 'POs raised';
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','sup_cur') >= 0 BEGIN CLOSE sup_cur; DEALLOCATE sup_cur; END
        EXEC util.usp_LogError @ProcName = 'inv.usp_RunReorder';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
