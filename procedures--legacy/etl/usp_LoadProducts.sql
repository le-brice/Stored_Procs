/* ============================================================
   etl.usp_LoadProducts
   Loads stg.RawProduct into dbo.Product. Set-based (no cursor here,
   for once). Auto-creates missing categories + suppliers by name.
   Cost/price arrive as TEXT -> TRY_CONVERT, bad ones become NULL.

   Upsert on Sku. Discontinued products in the feed are NOT
   reactivated (once DISCONTINUED, stays -- merchandising rule).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_LoadProducts
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_LoadProducts', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- categories
        INSERT INTO dbo.ProductCategory (CategoryName)
        SELECT DISTINCT LTRIM(RTRIM(r.CategoryName))
          FROM stg.RawProduct r
         WHERE r.IsProcessed = 0 AND r.CategoryName IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.ProductCategory c WHERE c.CategoryName = LTRIM(RTRIM(r.CategoryName)));

        -- suppliers
        INSERT INTO dbo.Supplier (SupplierName)
        SELECT DISTINCT LTRIM(RTRIM(r.SupplierName))
          FROM stg.RawProduct r
         WHERE r.IsProcessed = 0 AND r.SupplierName IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Supplier s WHERE s.SupplierName = LTRIM(RTRIM(r.SupplierName)));

        MERGE dbo.Product AS tgt
        USING (
            SELECT
                LTRIM(RTRIM(r.Sku)) AS Sku,
                MAX(r.ProductName)  AS ProductName,
                MAX(cat.CategoryId) AS CategoryId,
                MAX(sup.SupplierId) AS SupplierId,
                MAX(TRY_CONVERT(DECIMAL(18,4), r.UnitCost))  AS UnitCost,
                MAX(TRY_CONVERT(DECIMAL(18,4), r.ListPrice)) AS ListPrice
            FROM stg.RawProduct r
            LEFT JOIN dbo.ProductCategory cat ON cat.CategoryName = LTRIM(RTRIM(r.CategoryName))
            LEFT JOIN dbo.Supplier sup ON sup.SupplierName = LTRIM(RTRIM(r.SupplierName))
            WHERE r.IsProcessed = 0 AND r.Sku IS NOT NULL
            GROUP BY LTRIM(RTRIM(r.Sku))
        ) AS src ON tgt.Sku = src.Sku
        WHEN MATCHED THEN UPDATE SET
            ProductName = src.ProductName,
            CategoryId  = ISNULL(src.CategoryId, tgt.CategoryId),
            SupplierId  = ISNULL(src.SupplierId, tgt.SupplierId),
            UnitCost    = ISNULL(src.UnitCost, tgt.UnitCost),
            ListPrice   = ISNULL(src.ListPrice, tgt.ListPrice)
        WHEN NOT MATCHED THEN INSERT
            (Sku, ProductName, CategoryId, SupplierId, UnitCost, ListPrice, Status)
            VALUES (src.Sku, src.ProductName, src.CategoryId, src.SupplierId, src.UnitCost, src.ListPrice, 'ACTIVE');

        UPDATE stg.RawProduct SET IsProcessed = 1 WHERE IsProcessed = 0 AND Sku IS NOT NULL;

        EXEC util.usp_LogEnd @ProcLogId = @plog;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'etl.usp_LoadProducts', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
