/* ============================================================
   inv.usp_CreatePurchaseOrder
   Creates a DRAFT purchase order for a supplier + warehouse with a
   set of lines. Lines come in via the same colon/comma encoding as
   returns: @LineSpec = 'productId:qty:unitcost,...'. UnitCost is
   optional per line (falls back to Product.UnitCost).

   Bumps StockLevel.QtyOnOrder so the reorder job doesn't double up.
   Sets ExpectedDate = today + supplier lead time.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE inv.usp_CreatePurchaseOrder
    @SupplierId  INT,
    @WarehouseId INT,
    @LineSpec    VARCHAR(MAX),
    @PurchaseOrderId INT OUTPUT,
    @PoNumber    VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'inv.usp_CreatePurchaseOrder', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        DECLARE @lead INT, @ccy CHAR(3);
        SELECT @lead = LeadTimeDays FROM dbo.Supplier WHERE SupplierId = @SupplierId AND IsActive = 1;
        IF @lead IS NULL THROW 54001, 'Supplier not found or inactive', 1;

        -- supplier currency = supplier country default, else USD
        SELECT @ccy = ISNULL(co.DefaultCurrency, 'USD')
          FROM dbo.Supplier s LEFT JOIN ref.Country co ON co.CountryCode = s.CountryCode
         WHERE s.SupplierId = @SupplierId;

        EXEC util.usp_NextDocNumber @Prefix = 'PO', @DocNumber = @PoNumber OUTPUT;

        INSERT INTO inv.PurchaseOrder (PoNumber, SupplierId, WarehouseId, Status, OrderDate, ExpectedDate, CurrencyCode)
        VALUES (@PoNumber, @SupplierId, @WarehouseId, 'DRAFT',
                CAST(SYSUTCDATETIME() AS DATE),
                DATEADD(DAY, @lead, CAST(SYSUTCDATETIME() AS DATE)), @ccy);
        SET @PurchaseOrderId = SCOPE_IDENTITY();

        -- parse lines
        DECLARE @lines TABLE (ProductId INT, Qty INT, UnitCost DECIMAL(18,4));
        INSERT INTO @lines (ProductId, Qty, UnitCost)
        SELECT
            CAST(PARSENAME(REPLACE(value, ':', '.'), 3) AS INT),
            CAST(PARSENAME(REPLACE(value, ':', '.'), 2) AS INT),
            TRY_CONVERT(DECIMAL(18,4), PARSENAME(REPLACE(value, ':', '.'), 1))
        FROM STRING_SPLIT(@LineSpec, ',')
        WHERE LTRIM(RTRIM(value)) <> '';

        INSERT INTO inv.PurchaseOrderLine (PurchaseOrderId, ProductId, QtyOrdered, UnitCost)
        SELECT @PurchaseOrderId, l.ProductId, l.Qty, ISNULL(l.UnitCost, p.UnitCost)
          FROM @lines l JOIN dbo.Product p ON p.ProductId = l.ProductId;

        UPDATE inv.PurchaseOrder
           SET TotalCost = (SELECT SUM(QtyOrdered * UnitCost) FROM inv.PurchaseOrderLine WHERE PurchaseOrderId = @PurchaseOrderId)
         WHERE PurchaseOrderId = @PurchaseOrderId;

        -- reflect inbound on stock
        MERGE inv.StockLevel AS tgt
        USING (SELECT @WarehouseId AS wh, ProductId, SUM(QtyOrdered) AS q
                 FROM inv.PurchaseOrderLine WHERE PurchaseOrderId = @PurchaseOrderId GROUP BY ProductId) AS src
        ON tgt.WarehouseId = src.wh AND tgt.ProductId = src.ProductId
        WHEN MATCHED THEN UPDATE SET QtyOnOrder = tgt.QtyOnOrder + src.q
        WHEN NOT MATCHED THEN INSERT (WarehouseId, ProductId, QtyOnHand, QtyOnOrder)
             VALUES (src.wh, src.ProductId, 0, src.q);

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = @PoNumber;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'inv.usp_CreatePurchaseOrder';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
