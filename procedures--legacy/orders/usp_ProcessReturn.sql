/* ============================================================
   sales.usp_ProcessReturn
   End-to-end return: creates an RMA header+lines for the requested
   order lines, computes the refund (pro-rata of line total incl.
   tax), restocks if flagged via inv.usp_PostStockMovement (RETURN),
   refunds via a REFUNDED payment row, and claws back loyalty points
   through dbo.usp_AccrueLoyalty (negative accrual).

   @ReturnSpec is a comma list of OrderLineId:Qty pairs, e.g.
   '1001:2,1002:1'. Yes, really. The app team never gave us a TVP.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_ProcessReturn
    @OrderId    INT,
    @ReturnSpec VARCHAR(MAX),
    @Reason     VARCHAR(40) = NULL,
    @Restock    BIT = 1,
    @ReturnId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_ProcessReturn', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @status VARCHAR(20), @whId INT, @custId INT;
        SELECT @status = Status, @whId = WarehouseId, @custId = CustomerId
          FROM sales.OrderHeader WHERE OrderId = @OrderId;

        IF @status IS NULL THROW 52060, 'Order not found', 1;
        IF @status NOT IN ('SHIPPED','COMPLETED') THROW 52061, 'Only shipped/completed orders can be returned', 1;

        -- parse the spec into a temp table (split on comma, then colon)
        DECLARE @parsed TABLE (OrderLineId INT, Qty INT);
        INSERT INTO @parsed (OrderLineId, Qty)
        SELECT
            CAST(LEFT(value, CHARINDEX(':', value) - 1) AS INT),
            CAST(SUBSTRING(value, CHARINDEX(':', value) + 1, 50) AS INT)
        FROM STRING_SPLIT(@ReturnSpec, ',')
        WHERE LTRIM(RTRIM(value)) <> '';

        -- validate quantities against shipped-minus-already-returned
        IF EXISTS (
            SELECT 1 FROM @parsed p
            JOIN sales.OrderLine ol ON ol.OrderLineId = p.OrderLineId AND ol.OrderId = @OrderId
            WHERE p.Qty > (ol.QtyShipped - ol.QtyReturned)
        )
            THROW 52062, 'Return qty exceeds shipped quantity', 1;

        DECLARE @rma VARCHAR(20);
        EXEC util.usp_NextDocNumber @Prefix = 'RMA', @DocNumber = @rma OUTPUT;

        INSERT INTO sales.ReturnHeader (RmaNumber, OrderId, Reason, Status, RefundAmount)
        VALUES (@rma, @OrderId, @Reason, 'RECEIVED', 0);
        SET @ReturnId = SCOPE_IDENTITY();

        -- per-line refund = pro-rata of LineTotal (incl tax) by qty
        INSERT INTO sales.ReturnLine (ReturnId, OrderLineId, Qty, RefundAmount, Restock)
        SELECT @ReturnId, p.OrderLineId, p.Qty,
               ROUND(ol.LineTotal * p.Qty / NULLIF(ol.Qty, 0), 4),
               @Restock
          FROM @parsed p
          JOIN sales.OrderLine ol ON ol.OrderLineId = p.OrderLineId;

        -- restock
        IF @Restock = 1
        BEGIN
            DECLARE @pid INT, @qty INT;
            DECLARE rl_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT ol.ProductId, p.Qty
                  FROM @parsed p JOIN sales.OrderLine ol ON ol.OrderLineId = p.OrderLineId;
            OPEN rl_cur;
            FETCH NEXT FROM rl_cur INTO @pid, @qty;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC inv.usp_PostStockMovement
                     @WarehouseId = @whId, @ProductId = @pid, @MovementType = 'RETURN',
                     @Qty = @qty, @RefType = 'RETURN', @RefId = @ReturnId;
                FETCH NEXT FROM rl_cur INTO @pid, @qty;
            END
            CLOSE rl_cur; DEALLOCATE rl_cur;
        END

        -- bump QtyReturned on the order lines
        UPDATE ol
           SET QtyReturned = ol.QtyReturned + p.Qty
          FROM sales.OrderLine ol JOIN @parsed p ON p.OrderLineId = ol.OrderLineId;

        DECLARE @refund DECIMAL(18,4);
        SELECT @refund = ISNULL(SUM(RefundAmount), 0) FROM sales.ReturnLine WHERE ReturnId = @ReturnId;

        UPDATE sales.ReturnHeader SET RefundAmount = @refund, Status = 'REFUNDED' WHERE ReturnId = @ReturnId;

        INSERT INTO sales.Payment (OrderId, PaymentMethod, Amount, Status)
        SELECT @OrderId, 'STORECREDIT', -@refund, 'REFUNDED';

        -- claw back loyalty (negative). reuses the accrual proc with a flag.
        EXEC dbo.usp_AccrueLoyalty @OrderId = @OrderId, @CustomerId = @custId,
             @ReverseAmount = @refund;

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = @rma;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','rl_cur') >= 0 BEGIN CLOSE rl_cur; DEALLOCATE rl_cur; END
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'sales.usp_ProcessReturn';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
