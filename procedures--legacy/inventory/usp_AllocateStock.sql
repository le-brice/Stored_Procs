/* ============================================================
   inv.usp_AllocateStock
   Reserves up to @QtyRequested of a product at a warehouse by
   bumping QtyAllocated (never above QtyOnHand). Returns how much it
   actually managed to allocate via @QtyAllocated OUTPUT.

   Available = QtyOnHand - QtyAllocated. Does NOT move physical
   stock (that happens at ship time via usp_PostStockMovement).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_AllocateStock
    @WarehouseId  INT,
    @ProductId    INT,
    @QtyRequested INT,
    @QtyAllocated INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @QtyAllocated = 0;

    DECLARE @onHand INT, @alloc INT;
    SELECT @onHand = QtyOnHand, @alloc = QtyAllocated
      FROM inv.StockLevel WITH (UPDLOCK)
     WHERE WarehouseId = @WarehouseId AND ProductId = @ProductId;

    IF @onHand IS NULL
    BEGIN
        -- no stock record at all -> nothing available
        RETURN 0;
    END

    DECLARE @available INT = @onHand - @alloc;
    IF @available <= 0 RETURN 0;

    SET @QtyAllocated = CASE WHEN @QtyRequested <= @available THEN @QtyRequested ELSE @available END;

    UPDATE inv.StockLevel
       SET QtyAllocated = QtyAllocated + @QtyAllocated
     WHERE WarehouseId = @WarehouseId AND ProductId = @ProductId;

    RETURN 0;
END
GO
