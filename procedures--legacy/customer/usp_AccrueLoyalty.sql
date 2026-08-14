/* ============================================================
   dbo.usp_AccrueLoyalty
   Awards (or claws back) loyalty points for an order. Points are
   earned on the NET-OF-TAX value at a rate from config key
   'loyalty.points.per.currency.unit' (default 1 point per 1.00).

   If @ReverseAmount is supplied (>0) this REMOVES points
   proportional to that refunded amount instead of earning -- used
   by sales.usp_ProcessReturn. Yes, the dual behaviour is awkward.

   After moving points it re-evaluates the tier via
   dbo.usp_RecalcLoyaltyTier.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_AccrueLoyalty
    @OrderId       INT,
    @CustomerId    INT,
    @ReverseAmount DECIMAL(18,4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @acctId INT;
    EXEC dbo.usp_GetOrCreateLoyaltyAccount @CustomerId = @CustomerId, @LoyaltyAccountId = @acctId OUTPUT;

    DECLARE @rateTxt VARCHAR(400), @rate DECIMAL(18,6);
    EXEC util.usp_GetConfig @ParamKey = 'loyalty.points.per.currency.unit', @Default = '1', @Value = @rateTxt OUTPUT;
    SET @rate = TRY_CONVERT(DECIMAL(18,6), @rateTxt);
    IF @rate IS NULL SET @rate = 1;

    DECLARE @points INT, @txnType VARCHAR(20), @note VARCHAR(200);

    IF @ReverseAmount IS NOT NULL AND @ReverseAmount > 0
    BEGIN
        -- reversal: refund amount is gross (incl tax); strip tax roughly using
        -- the order's blended tax. (this is an approximation, FIN never liked it)
        DECLARE @grand DECIMAL(18,4), @tax DECIMAL(18,4);
        SELECT @grand = GrandTotal, @tax = TaxTotal FROM sales.OrderHeader WHERE OrderId = @OrderId;
        DECLARE @netFactor DECIMAL(18,6) = CASE WHEN @grand = 0 THEN 1 ELSE (@grand - @tax) / @grand END;
        SET @points = -1 * CAST(FLOOR(@ReverseAmount * @netFactor * @rate) AS INT);
        SET @txnType = 'REDEEM';   -- reuse REDEEM bucket for clawback. historical.
        SET @note = 'return clawback order ' + CAST(@OrderId AS VARCHAR(12));
    END
    ELSE
    BEGIN
        DECLARE @net DECIMAL(18,4);
        SELECT @net = (SubTotal - DiscountTotal) FROM sales.OrderHeader WHERE OrderId = @OrderId;
        IF @net < 0 SET @net = 0;
        SET @points = CAST(FLOOR(@net * @rate) AS INT);
        SET @txnType = 'EARN';
        SET @note = 'earn order ' + CAST(@OrderId AS VARCHAR(12));
    END

    IF @points <> 0
    BEGIN
        INSERT INTO dbo.LoyaltyTransaction (LoyaltyAccountId, TxnType, Points, OrderId, Note)
        VALUES (@acctId, @txnType, @points, @OrderId, @note);

        UPDATE dbo.LoyaltyAccount
           SET PointsBalance  = PointsBalance + @points,
               LifetimePoints = LifetimePoints + CASE WHEN @points > 0 THEN @points ELSE 0 END
         WHERE LoyaltyAccountId = @acctId;
    END

    EXEC dbo.usp_RecalcLoyaltyTier @CustomerId = @CustomerId;
END
GO
