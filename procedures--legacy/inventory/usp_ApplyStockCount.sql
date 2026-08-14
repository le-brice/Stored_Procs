/* ============================================================
   inv.usp_ApplyStockCount
   Reconciles a physical stock count against the system QtyOnHand for
   one product/warehouse. Posts an ADJUST movement for the signed
   difference (counted - system) and stamps LastCountedUtc.

   Big variances (> config 'stockcount.variance.alert', default 25
   units) get a row in util.ErrorLog as a soft warning even though
   nothing actually errored. (yes, abusing ErrorLog as an alert
   table. INV-90.)
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_ApplyStockCount
    @WarehouseId INT,
    @ProductId   INT,
    @CountedQty  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @onHand INT;
    SELECT @onHand = QtyOnHand FROM inv.StockLevel WHERE WarehouseId = @WarehouseId AND ProductId = @ProductId;
    IF @onHand IS NULL SET @onHand = 0;

    DECLARE @diff INT = @CountedQty - @onHand;

    IF @diff <> 0
        EXEC inv.usp_PostStockMovement
             @WarehouseId = @WarehouseId, @ProductId = @ProductId,
             @MovementType = 'ADJUST', @Qty = @diff, @RefType = 'MANUAL';

    UPDATE inv.StockLevel SET LastCountedUtc = SYSUTCDATETIME()
     WHERE WarehouseId = @WarehouseId AND ProductId = @ProductId;

    DECLARE @alertTxt VARCHAR(400);
    EXEC util.usp_GetConfig @ParamKey = 'stockcount.variance.alert', @Default = '25', @Value = @alertTxt OUTPUT;
    IF ABS(@diff) > TRY_CONVERT(INT, @alertTxt)
        INSERT INTO util.ErrorLog (ProcName, ErrorNumber, ErrorMessage)
        VALUES ('inv.usp_ApplyStockCount', 0,
                CONCAT('Large stock count variance wh=', @WarehouseId, ' prod=', @ProductId, ' diff=', @diff));
END
GO
