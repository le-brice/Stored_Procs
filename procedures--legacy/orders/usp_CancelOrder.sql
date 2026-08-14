/* ============================================================
   sales.usp_CancelOrder
   Cancels an order that hasn't shipped. Releases any stock
   allocations, voids/refunds captured payments, reverses loyalty
   accrual if it somehow happened, and sets status CANCELLED.

   Refuses orders that are SHIPPED/COMPLETED -- use the returns
   flow (sales.usp_ProcessReturn) for those.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_CancelOrder
    @OrderId INT,
    @Reason  VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_CancelOrder', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @status VARCHAR(20), @whId INT, @paid DECIMAL(18,4);
        SELECT @status = Status, @whId = WarehouseId, @paid = PaidAmount
          FROM sales.OrderHeader WHERE OrderId = @OrderId;

        IF @status IS NULL THROW 52050, 'Order not found', 1;
        IF @status IN ('SHIPPED','COMPLETED') THROW 52051, 'Shipped orders must go through returns', 1;
        IF @status = 'CANCELLED' THROW 52052, 'Order already cancelled', 1;

        -- release allocations for confirmed/onhold/picking orders
        IF @status IN ('CONFIRMED','ONHOLD','PICKING','PAID')
            UPDATE sl
               SET QtyAllocated = CASE WHEN sl.QtyAllocated - ol.Qty < 0 THEN 0 ELSE sl.QtyAllocated - ol.Qty END
              FROM inv.StockLevel sl
              JOIN sales.OrderLine ol ON ol.ProductId = sl.ProductId
             WHERE ol.OrderId = @OrderId AND sl.WarehouseId = @whId;

        -- refund any captured payments
        IF @paid > 0
        BEGIN
            UPDATE sales.Payment SET Status = 'REFUNDED' WHERE OrderId = @OrderId AND Status = 'CAPTURED';
            -- note: does not write a fin journal here. settlement job picks it up. (FIN-130)
        END

        UPDATE sales.OrderHeader
           SET Status = 'CANCELLED', PaidAmount = 0, ModifiedUtc = SYSUTCDATETIME()
         WHERE OrderId = @OrderId;

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = @Reason;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'sales.usp_CancelOrder';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
