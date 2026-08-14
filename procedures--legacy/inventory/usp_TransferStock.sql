/* ============================================================
   inv.usp_TransferStock
   Moves stock between two warehouses for a single product. Posts a
   TRANSFER_OUT at the source and a TRANSFER_IN at the destination
   (two movements, one logical transfer). Refuses to move more than
   the available (on hand minus allocated) at the source.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_TransferStock
    @FromWarehouseId INT,
    @ToWarehouseId   INT,
    @ProductId       INT,
    @Qty             INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'inv.usp_TransferStock', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        IF @Qty <= 0 THROW 54020, 'Qty must be positive', 1;
        IF @FromWarehouseId = @ToWarehouseId THROW 54021, 'Source and destination are the same', 1;

        DECLARE @onHand INT, @alloc INT;
        SELECT @onHand = QtyOnHand, @alloc = QtyAllocated
          FROM inv.StockLevel WITH (UPDLOCK)
         WHERE WarehouseId = @FromWarehouseId AND ProductId = @ProductId;

        IF @onHand IS NULL OR (@onHand - @alloc) < @Qty
            THROW 54022, 'Insufficient available stock at source', 1;

        EXEC inv.usp_PostStockMovement
             @WarehouseId = @FromWarehouseId, @ProductId = @ProductId,
             @MovementType = 'TRANSFER_OUT', @Qty = @Qty, @RefType = 'MANUAL';

        EXEC inv.usp_PostStockMovement
             @WarehouseId = @ToWarehouseId, @ProductId = @ProductId,
             @MovementType = 'TRANSFER_IN', @Qty = @Qty, @RefType = 'MANUAL';

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @Qty;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'inv.usp_TransferStock';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
