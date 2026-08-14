/* ============================================================
   inv.usp_PostStockMovement
   The single choke-point for changing QtyOnHand. Writes a row to
   inv.StockMovement and adjusts inv.StockLevel.QtyOnHand by a
   signed delta derived from MovementType:

     RECEIPT, RETURN, TRANSFER_IN, ADJUST(+)  -> +Qty
     SHIP, TRANSFER_OUT, ADJUST(-)            -> -Qty

   Callers pass Qty as a POSITIVE magnitude; the sign is applied
   here based on type. (ADJUST is the exception -- pass it signed.)

   Creates the StockLevel row if missing. Pulls UnitCost from the
   product standard cost if not supplied (for movement valuation).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_PostStockMovement
    @WarehouseId  INT,
    @ProductId    INT,
    @MovementType VARCHAR(20),
    @Qty          INT,
    @RefType      VARCHAR(20) = NULL,
    @RefId        INT = NULL,
    @UnitCost     DECIMAL(18,4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @UnitCost IS NULL
        SELECT @UnitCost = UnitCost FROM dbo.Product WHERE ProductId = @ProductId;

    DECLARE @delta INT =
        CASE @MovementType
            WHEN 'RECEIPT'      THEN  ABS(@Qty)
            WHEN 'RETURN'       THEN  ABS(@Qty)
            WHEN 'TRANSFER_IN'  THEN  ABS(@Qty)
            WHEN 'SHIP'         THEN -ABS(@Qty)
            WHEN 'TRANSFER_OUT' THEN -ABS(@Qty)
            WHEN 'ADJUST'       THEN  @Qty          -- caller-signed
            ELSE @Qty
        END;

    -- ensure stock level row exists
    IF NOT EXISTS (SELECT 1 FROM inv.StockLevel WHERE WarehouseId = @WarehouseId AND ProductId = @ProductId)
        INSERT INTO inv.StockLevel (WarehouseId, ProductId, QtyOnHand) VALUES (@WarehouseId, @ProductId, 0);

    INSERT INTO inv.StockMovement (WarehouseId, ProductId, MovementType, Qty, RefType, RefId, UnitCost)
    VALUES (@WarehouseId, @ProductId, @MovementType, @delta, @RefType, @RefId, @UnitCost);

    UPDATE inv.StockLevel
       SET QtyOnHand = QtyOnHand + @delta
     WHERE WarehouseId = @WarehouseId AND ProductId = @ProductId;
END
GO
