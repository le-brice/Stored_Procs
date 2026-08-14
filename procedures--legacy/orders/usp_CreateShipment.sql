/* ============================================================
   sales.usp_CreateShipment
   Ships outstanding (unshipped) quantity for a PAID order. Creates
   a Shipment + ShipmentLines, posts SHIP stock movements via
   inv.usp_PostStockMovement, decrements allocation, updates
   OrderLine.QtyShipped, and flips the order to SHIPPED (or
   COMPLETED if fully shipped). Awards loyalty points via
   dbo.usp_AccrueLoyalty.

   Partial shipments allowed -- call repeatedly.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_CreateShipment
    @OrderId   INT,
    @Carrier   VARCHAR(40) = NULL,
    @TrackingNo VARCHAR(60) = NULL,
    @ShipmentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_CreateShipment', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @status VARCHAR(20), @whId INT, @custId INT;
        SELECT @status = Status, @whId = WarehouseId, @custId = CustomerId
          FROM sales.OrderHeader WHERE OrderId = @OrderId;

        IF @status IS NULL THROW 52040, 'Order not found', 1;
        IF @status NOT IN ('PAID','PICKING','SHIPPED') THROW 52041, 'Order not in a shippable status', 1;

        -- what's left to ship
        IF NOT EXISTS (SELECT 1 FROM sales.OrderLine WHERE OrderId = @OrderId AND Qty > QtyShipped)
            THROW 52042, 'Nothing left to ship', 1;

        INSERT INTO sales.Shipment (OrderId, WarehouseId, Carrier, TrackingNo, Status, ShippedUtc)
        VALUES (@OrderId, @whId, @Carrier, @TrackingNo, 'SHIPPED', SYSUTCDATETIME());
        SET @ShipmentId = SCOPE_IDENTITY();

        DECLARE @ol INT, @pid INT, @toShip INT;
        DECLARE ship_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT OrderLineId, ProductId, (Qty - QtyShipped)
              FROM sales.OrderLine WHERE OrderId = @OrderId AND Qty > QtyShipped;
        OPEN ship_cur;
        FETCH NEXT FROM ship_cur INTO @ol, @pid, @toShip;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO sales.ShipmentLine (ShipmentId, OrderLineId, Qty)
            VALUES (@ShipmentId, @ol, @toShip);

            -- physical stock out (negative qty), and release the allocation
            EXEC inv.usp_PostStockMovement
                 @WarehouseId = @whId, @ProductId = @pid, @MovementType = 'SHIP',
                 @Qty = @toShip, @RefType = 'ORDER', @RefId = @OrderId;

            UPDATE inv.StockLevel
               SET QtyAllocated = CASE WHEN QtyAllocated - @toShip < 0 THEN 0 ELSE QtyAllocated - @toShip END
             WHERE WarehouseId = @whId AND ProductId = @pid;

            UPDATE sales.OrderLine SET QtyShipped = QtyShipped + @toShip WHERE OrderLineId = @ol;

            FETCH NEXT FROM ship_cur INTO @ol, @pid, @toShip;
        END
        CLOSE ship_cur; DEALLOCATE ship_cur;

        -- status: fully shipped => COMPLETED else SHIPPED
        IF NOT EXISTS (SELECT 1 FROM sales.OrderLine WHERE OrderId = @OrderId AND Qty > QtyShipped)
            UPDATE sales.OrderHeader SET Status = 'COMPLETED', ModifiedUtc = SYSUTCDATETIME() WHERE OrderId = @OrderId;
        ELSE
            UPDATE sales.OrderHeader SET Status = 'SHIPPED', ModifiedUtc = SYSUTCDATETIME() WHERE OrderId = @OrderId;

        -- loyalty accrual on the shipped value (net of tax). pulls config rate.
        EXEC dbo.usp_AccrueLoyalty @OrderId = @OrderId, @CustomerId = @custId;

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = @TrackingNo;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ship_cur') >= 0 BEGIN CLOSE ship_cur; DEALLOCATE ship_cur; END
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'sales.usp_CreateShipment';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
