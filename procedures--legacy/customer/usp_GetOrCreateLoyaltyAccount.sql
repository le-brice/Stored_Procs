/* ============================================================
   dbo.usp_GetOrCreateLoyaltyAccount
   Returns the LoyaltyAccountId for a customer, creating a BRONZE
   account on the fly if one doesn't exist. Auto-enrolment was a
   2020 marketing decision (LOYALTY-22).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetOrCreateLoyaltyAccount
    @CustomerId      INT,
    @LoyaltyAccountId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @LoyaltyAccountId = LoyaltyAccountId
      FROM dbo.LoyaltyAccount WHERE CustomerId = @CustomerId;

    IF @LoyaltyAccountId IS NULL
    BEGIN
        INSERT INTO dbo.LoyaltyAccount (CustomerId, Tier, PointsBalance, LifetimePoints)
        VALUES (@CustomerId, 'BRONZE', 0, 0);
        SET @LoyaltyAccountId = SCOPE_IDENTITY();
    END
END
GO
