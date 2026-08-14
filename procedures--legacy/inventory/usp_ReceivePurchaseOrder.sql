/* ============================================================
   inv.usp_ReceivePurchaseOrder
   Receives stock against a PO. @ReceiptSpec = 'poLineId:qty,...';
   if NULL, receives ALL outstanding quantity on every line.

   For each received qty: posts a RECEIPT movement (which bumps
   QtyOnHand), reduces QtyOnOrder, bumps QtyReceived on the PO line.
   PO status -> PARTIAL or RECEIVED.

   Note: receipt UnitCost is taken from the PO line, and we ALSO
   update Product.UnitCost to the latest receipt cost (moving "last
   cost", not weighted average -- finance keeps asking us to change
   this to WAC, see FIN-205, never prioritised).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_ReceivePurchaseOrder
    @PurchaseOrderId INT,
    @ReceiptSpec     VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'inv.usp_ReceivePurchaseOrder', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @whId INT, @status VARCHAR(20);
        SELECT @whId = WarehouseId, @status = Status FROM inv.PurchaseOrder WHERE PurchaseOrderId = @PurchaseOrderId;
        IF @whId IS NULL THROW 54010, 'PO not found', 1;
        IF @status IN ('RECEIVED','CANCELLED') THROW 54011, 'PO already closed', 1;

        DECLARE @recv TABLE (PoLineId INT, Qty INT);
        IF @ReceiptSpec IS NULL
            INSERT INTO @recv (PoLineId, Qty)
            SELECT PoLineId, QtyOrdered - QtyReceived
              FROM inv.PurchaseOrderLine
             WHERE PurchaseOrderId = @PurchaseOrderId AND QtyOrdered > QtyReceived;
        ELSE
            INSERT INTO @recv (PoLineId, Qty)
            SELECT CAST(LEFT(value, CHARINDEX(':', value)-1) AS INT),
                   CAST(SUBSTRING(value, CHARINDEX(':', value)+1, 50) AS INT)
              FROM STRING_SPLIT(@ReceiptSpec, ',') WHERE LTRIM(RTRIM(value)) <> '';

        DECLARE @poLine INT, @pid INT, @qty INT, @cost DECIMAL(18,4);
        DECLARE rc_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT r.PoLineId, pol.ProductId, r.Qty, pol.UnitCost
              FROM @recv r JOIN inv.PurchaseOrderLine pol ON pol.PoLineId = r.PoLineId
             WHERE r.Qty > 0;
        OPEN rc_cur;
        FETCH NEXT FROM rc_cur INTO @poLine, @pid, @qty, @cost;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC inv.usp_PostStockMovement
                 @WarehouseId = @whId, @ProductId = @pid, @MovementType = 'RECEIPT',
                 @Qty = @qty, @RefType = 'PO', @RefId = @PurchaseOrderId, @UnitCost = @cost;

            UPDATE inv.PurchaseOrderLine SET QtyReceived = QtyReceived + @qty WHERE PoLineId = @poLine;

            UPDATE inv.StockLevel
               SET QtyOnOrder = CASE WHEN QtyOnOrder - @qty < 0 THEN 0 ELSE QtyOnOrder - @qty END
             WHERE WarehouseId = @whId AND ProductId = @pid;

            -- last-cost update (FIN-205)
            UPDATE dbo.Product SET UnitCost = @cost WHERE ProductId = @pid;

            FETCH NEXT FROM rc_cur INTO @poLine, @pid, @qty, @cost;
        END
        CLOSE rc_cur; DEALLOCATE rc_cur;

        -- recompute PO status
        IF NOT EXISTS (SELECT 1 FROM inv.PurchaseOrderLine WHERE PurchaseOrderId = @PurchaseOrderId AND QtyReceived < QtyOrdered)
            UPDATE inv.PurchaseOrder SET Status = 'RECEIVED' WHERE PurchaseOrderId = @PurchaseOrderId;
        ELSE
            UPDATE inv.PurchaseOrder SET Status = 'PARTIAL' WHERE PurchaseOrderId = @PurchaseOrderId;

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','rc_cur') >= 0 BEGIN CLOSE rc_cur; DEALLOCATE rc_cur; END
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'inv.usp_ReceivePurchaseOrder';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
