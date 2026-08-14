/* ============================================================
   rpt.usp_BuildDailySales
   (Re)builds rpt.DailySalesSummary for a business date: order
   counts, units, gross/net revenue and discount by warehouse +
   category. EstMargin uses Product.UnitCost as cost basis.

   Revenue is taken in ORDER currency and NOT converted -- this
   report is "as billed". (Whereas the finance journal is in USD.
   This trips people up constantly. RPT-31.)

   Idempotent: deletes the date's rows first.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE rpt.usp_BuildDailySales
    @BusinessDate DATE,
    @BatchId      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'rpt.usp_BuildDailySales', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        DELETE FROM rpt.DailySalesSummary WHERE SummaryDate = @BusinessDate;

        ;WITH lines AS (
            SELECT
                oh.WarehouseId,
                ISNULL(p.CategoryId, 0) AS CategoryId,
                oh.OrderId,
                ol.Qty,
                (ol.UnitPrice * ol.Qty)        AS Gross,
                ol.LineDiscount,
                (ol.UnitPrice * ol.Qty - ol.LineDiscount) AS Net,
                (ol.Qty * ISNULL(p.UnitCost, 0)) AS Cost
            FROM sales.OrderHeader oh
            JOIN sales.OrderLine ol ON ol.OrderId = oh.OrderId
            JOIN dbo.Product p ON p.ProductId = ol.ProductId
            WHERE CAST(oh.OrderDate AS DATE) = @BusinessDate
              AND oh.Status NOT IN ('CANCELLED','NEW')
              AND oh.WarehouseId IS NOT NULL
        )
        INSERT INTO rpt.DailySalesSummary
            (SummaryDate, WarehouseId, CategoryId, OrderCount, UnitsSold,
             GrossRevenue, DiscountTotal, NetRevenue, EstMargin)
        SELECT
            @BusinessDate,
            WarehouseId,
            CategoryId,
            COUNT(DISTINCT OrderId),
            SUM(Qty),
            SUM(Gross),
            SUM(LineDiscount),
            SUM(Net),
            SUM(Net) - SUM(Cost)
        FROM lines
        GROUP BY WarehouseId, CategoryId;

        DECLARE @rows INT = @@ROWCOUNT;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @rows;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'rpt.usp_BuildDailySales', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
