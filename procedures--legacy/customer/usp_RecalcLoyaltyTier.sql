/* ============================================================
   dbo.usp_RecalcLoyaltyTier
   Sets the loyalty tier from LifetimePoints. Thresholds are
   HARDCODED here (and ALSO in a CASE inside rpt.usp_BuildCustomerLtv
   -- they have drifted, GOLD is 10000 here but 12000 there. nobody
   has reconciled this. LOYALTY-44).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_RecalcLoyaltyTier
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.LoyaltyAccount
       SET Tier = CASE
                    WHEN LifetimePoints >= 50000 THEN 'PLATINUM'
                    WHEN LifetimePoints >= 10000 THEN 'GOLD'
                    WHEN LifetimePoints >= 2500  THEN 'SILVER'
                    ELSE 'BRONZE'
                  END
     WHERE CustomerId = @CustomerId;
END
GO
