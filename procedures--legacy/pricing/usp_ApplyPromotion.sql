/* ============================================================
   sales.usp_ApplyPromotion
   Validates a promo against an order, computes the discount, writes
   it to OrderHeader.DiscountTotal + PromotionId, logs a redemption,
   and bumps Promotion.TimesRedeemed.

   NB: this calls sales.usp_RecalcOrderTotals afterwards. The promo
   discount is applied at the HEADER level, not per line. There was a
   half-finished attempt to do per-line BOGO -- see the commented
   block below, left in deliberately.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_ApplyPromotion
    @OrderId   INT,
    @PromoCode VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_ApplyPromotion', @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        DECLARE @subtotal DECIMAL(18,4), @orderDate DATE, @promotionId INT,
                @isValid BIT, @reason VARCHAR(200), @discount DECIMAL(18,4) = 0,
                @promoType VARCHAR(20), @pct DECIMAL(6,3), @amt DECIMAL(18,4),
                @catId INT;

        SELECT @subtotal = SubTotal, @orderDate = CAST(OrderDate AS DATE)
          FROM sales.OrderHeader WHERE OrderId = @OrderId;

        EXEC sales.usp_ValidatePromotion
             @PromoCode = @PromoCode,
             @SubTotal = @subtotal,
             @AsOfDate = @orderDate,
             @PromotionId = @promotionId OUTPUT,
             @IsValid = @isValid OUTPUT,
             @Reason = @reason OUTPUT;

        IF @isValid = 0
            THROW 51001, @reason, 1;

        SELECT @promoType = PromoType, @pct = DiscountPct,
               @amt = DiscountAmt, @catId = CategoryId
          FROM sales.Promotion WHERE PromotionId = @promotionId;

        IF @promoType = 'PCT'
        BEGIN
            -- category-restricted percentage only discounts matching lines
            IF @catId IS NOT NULL
                SELECT @discount = ISNULL(SUM(ol.UnitPrice * ol.Qty), 0) * (@pct / 100.0)
                  FROM sales.OrderLine ol
                  JOIN dbo.Product p ON p.ProductId = ol.ProductId
                 WHERE ol.OrderId = @OrderId AND p.CategoryId = @catId;
            ELSE
                SET @discount = @subtotal * (@pct / 100.0);
        END
        ELSE IF @promoType = 'AMOUNT'
            SET @discount = @amt;
        ELSE IF @promoType = 'FREESHIP'
            SET @discount = 0;  -- handled in shipping calc, flagged via PromotionId
        -- ELSE IF @promoType = 'BOGO'
        -- BEGIN
        --     -- TODO per-line buy-one-get-one. never finished. do NOT enable.
        --     EXEC sales.usp_ApplyBogo @OrderId = @OrderId, @PromotionId = @promotionId;
        -- END

        IF @discount > @subtotal SET @discount = @subtotal;   -- clamp

        UPDATE sales.OrderHeader
           SET PromotionId = @promotionId,
               DiscountTotal = @discount,
               ModifiedUtc = SYSUTCDATETIME()
         WHERE OrderId = @OrderId;

        INSERT INTO sales.PromotionRedemption (PromotionId, OrderId, DiscountApplied)
        VALUES (@promotionId, @OrderId, @discount);

        UPDATE sales.Promotion
           SET TimesRedeemed = TimesRedeemed + 1
         WHERE PromotionId = @promotionId;

        EXEC sales.usp_RecalcOrderTotals @OrderId = @OrderId;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = @PromoCode;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'sales.usp_ApplyPromotion';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED', @Message = 'see ErrorLog';
        THROW;
    END CATCH
END
GO
