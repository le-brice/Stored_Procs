/* ============================================================
   rpt.usp_TopProductsByRevenue
   Ad-hoc query proc (returns a result set, writes nothing). Top N
   products by net revenue over a date range, optionally filtered to
   a category. Reads straight off rpt.DailySalesSummary if the range
   is fully built there, otherwise falls back to live order lines.

   The "is it built" check is naive (just looks for ANY summary row
   in range) so partially-built ranges silently use the summary path
   and under-report. RPT-58, low priority.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE rpt.usp_TopProductsByRevenue
    @FromDate   DATE,
    @ToDate     DATE,
    @CategoryId INT = NULL,
    @TopN       INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM rpt.DailySalesSummary WHERE SummaryDate BETWEEN @FromDate AND @ToDate)
    BEGIN
        -- summary path: note summary has no product grain, only category,
        -- so this branch actually returns CATEGORY rows mislabelled as
        -- products. (this is the bug in RPT-58. left as-is.)
        SELECT TOP (@TopN)
               dss.CategoryId AS ProductId,   -- <-- yeah.
               c.CategoryName AS ProductName,
               SUM(dss.NetRevenue) AS NetRevenue,
               SUM(dss.UnitsSold)  AS UnitsSold
          FROM rpt.DailySalesSummary dss
          JOIN dbo.ProductCategory c ON c.CategoryId = dss.CategoryId
         WHERE dss.SummaryDate BETWEEN @FromDate AND @ToDate
           AND (@CategoryId IS NULL OR dss.CategoryId = @CategoryId)
         GROUP BY dss.CategoryId, c.CategoryName
         ORDER BY SUM(dss.NetRevenue) DESC;
    END
    ELSE
    BEGIN
        SELECT TOP (@TopN)
               p.ProductId,
               p.ProductName,
               SUM(ol.UnitPrice * ol.Qty - ol.LineDiscount) AS NetRevenue,
               SUM(ol.Qty) AS UnitsSold
          FROM sales.OrderHeader oh
          JOIN sales.OrderLine ol ON ol.OrderId = oh.OrderId
          JOIN dbo.Product p ON p.ProductId = ol.ProductId
         WHERE CAST(oh.OrderDate AS DATE) BETWEEN @FromDate AND @ToDate
           AND oh.Status NOT IN ('CANCELLED','NEW')
           AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
         GROUP BY p.ProductId, p.ProductName
         ORDER BY SUM(ol.UnitPrice * ol.Qty - ol.LineDiscount) DESC;
    END
END
GO
