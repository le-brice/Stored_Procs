/* ============================================================
   sales.usp_ConfirmOrder
   Moves an order NEW -> CONFIRMED. Allocates stock for every line
   against the order's warehouse via inv.usp_AllocateStock. If any
   line can't be fully allocated the order goes ONHOLD instead
   (unless @AllowBackorder = 1, then it confirms anyway and the
   shortfall becomes QtyOnOrder pressure for the reorder job).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_ConfirmOrder
    @OrderId        INT,
    @AllowBackorder BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_ConfirmOrder', @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        DECLARE @status VARCHAR(20), @whId INT;
        SELECT @status = Status, @whId = WarehouseId
          FROM sales.OrderHeader WHERE OrderId = @OrderId;

        IF @status IS NULL THROW 52020, 'Order not found', 1;
        IF @status <> 'NEW' THROW 52021, 'Only NEW orders can be confirmed', 1;
        IF @whId IS NULL THROW 52022, 'Order has no warehouse assigned', 1;
        IF NOT EXISTS (SELECT 1 FROM sales.OrderLine WHERE OrderId = @OrderId)
            THROW 52023, 'Cannot confirm an empty order', 1;

        DECLARE @shortfall BIT = 0;

        -- walk the lines; old-school cursor, never got rewritten as set-based
        DECLARE @ol INT, @pid INT, @qty INT, @allocated INT;
        DECLARE line_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT OrderLineId, ProductId, Qty FROM sales.OrderLine WHERE OrderId = @OrderId;
        OPEN line_cur;
        FETCH NEXT FROM line_cur INTO @ol, @pid, @qty;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC inv.usp_AllocateStock
                 @WarehouseId = @whId, @ProductId = @pid, @QtyRequested = @qty,
                 @QtyAllocated = @allocated OUTPUT;
            IF @allocated < @qty SET @shortfall = 1;
            FETCH NEXT FROM line_cur INTO @ol, @pid, @qty;
        END
        CLOSE line_cur; DEALLOCATE line_cur;

        IF @shortfall = 1 AND @AllowBackorder = 0
            UPDATE sales.OrderHeader SET Status = 'ONHOLD', ModifiedUtc = SYSUTCDATETIME() WHERE OrderId = @OrderId;
        ELSE
            UPDATE sales.OrderHeader SET Status = 'CONFIRMED', ModifiedUtc = SYSUTCDATETIME() WHERE OrderId = @OrderId;

        EXEC util.usp_LogEnd @ProcLogId = @plog,
             @Message = CASE WHEN @shortfall = 1 THEN 'shortfall' ELSE 'ok' END;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','line_cur') >= 0 BEGIN CLOSE line_cur; DEALLOCATE line_cur; END
        EXEC util.usp_LogError @ProcName = 'sales.usp_ConfirmOrder';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
