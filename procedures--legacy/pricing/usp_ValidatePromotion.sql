/* ============================================================
   sales.usp_ValidatePromotion
   Checks whether a promo code can be applied to an order subtotal.
   Returns @IsValid bit + @Reason. Does NOT apply anything.
   Called by sales.usp_ApplyPromotion and by the cart layer.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_ValidatePromotion
    @PromoCode   VARCHAR(30),
    @SubTotal    DECIMAL(18,4),
    @AsOfDate    DATE = NULL,
    @PromotionId INT OUTPUT,
    @IsValid     BIT OUTPUT,
    @Reason      VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOfDate IS NULL SET @AsOfDate = CAST(SYSUTCDATETIME() AS DATE);
    SET @IsValid = 0;
    SET @Reason = NULL;
    SET @PromotionId = NULL;

    DECLARE @minSpend DECIMAL(18,4), @maxRedemptions INT, @timesRedeemed INT,
            @effFrom DATE, @effTo DATE, @active BIT;

    SELECT @PromotionId   = PromotionId,
           @minSpend      = MinSpend,
           @maxRedemptions= MaxRedemptions,
           @timesRedeemed = TimesRedeemed,
           @effFrom       = EffectiveFrom,
           @effTo         = EffectiveTo,
           @active        = IsActive
      FROM sales.Promotion
     WHERE PromoCode = @PromoCode;

    IF @PromotionId IS NULL
    BEGIN
        SET @Reason = 'Unknown promo code';
        RETURN 0;
    END

    IF @active = 0
    BEGIN
        SET @Reason = 'Promotion inactive';
        RETURN 0;
    END

    IF @AsOfDate < @effFrom OR (@effTo IS NOT NULL AND @AsOfDate > @effTo)
    BEGIN
        SET @Reason = 'Promotion not in effective window';
        RETURN 0;
    END

    IF @minSpend IS NOT NULL AND @SubTotal < @minSpend
    BEGIN
        SET @Reason = 'Subtotal below minimum spend';
        RETURN 0;
    END

    IF @maxRedemptions IS NOT NULL AND @timesRedeemed >= @maxRedemptions
    BEGIN
        SET @Reason = 'Promotion fully redeemed';
        RETURN 0;
    END

    SET @IsValid = 1;
    RETURN 0;
END
GO
