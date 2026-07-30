/* ============================================================
   etl.usp_ImportRawOrders
   The big one. Turns flat stg.RawOrder rows (one row per order
   LINE, grouped by ExternalOrderRef) into real orders by driving
   the same procs the app uses: usp_CreateOrder, usp_AddOrderLine,
   usp_ApplyPromotion, usp_ConfirmOrder.

   This is deliberately built on the OLTP procs so imported orders
   go through identical pricing/tax/loyalty logic. It's slow and
   cursor-heavy. Rejected rows get RejectReason stamped and are left
   unprocessed for a human to look at.

   Assumes etl.usp_LoadCustomers + usp_LoadProducts already ran this
   batch (it resolves CustomerNo / Sku to ids and rejects if missing).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_ImportRawOrders
    @BatchId UNIQUEIDENTIFIER = NULL,
    @AutoConfirm BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_ImportRawOrders', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- pre-flight validation: stamp reject reasons, don't import bad lines
        UPDATE r
           SET RejectReason =
                CASE
                    WHEN r.CustomerNo IS NULL THEN 'missing customer no'
                    WHEN c.CustomerId IS NULL THEN 'unknown customer ' + r.CustomerNo
                    WHEN p.ProductId IS NULL THEN 'unknown sku ' + ISNULL(r.Sku,'(null)')
                    WHEN TRY_CONVERT(INT, r.Qty) IS NULL OR TRY_CONVERT(INT, r.Qty) <= 0 THEN 'bad qty'
                    ELSE NULL
                END
          FROM stg.RawOrder r
          LEFT JOIN dbo.Customer c ON c.CustomerNo = r.CustomerNo AND c.Status = 'ACTIVE'
          LEFT JOIN dbo.Product  p ON p.Sku = r.Sku AND p.Status = 'ACTIVE'
         WHERE r.IsProcessed = 0;

        -- one order per ExternalOrderRef where ALL its lines are clean
        DECLARE @extRef VARCHAR(60), @custNo VARCHAR(50), @ccy CHAR(3), @promo VARCHAR(40);
        DECLARE @custId INT, @orderId INT, @orderNo VARCHAR(20);

        DECLARE ord_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT r.ExternalOrderRef, MAX(r.CustomerNo), MAX(r.CurrencyCode), MAX(r.PromoCode)
              FROM stg.RawOrder r
             WHERE r.IsProcessed = 0
             GROUP BY r.ExternalOrderRef
            HAVING SUM(CASE WHEN r.RejectReason IS NOT NULL THEN 1 ELSE 0 END) = 0
               AND MAX(r.ExternalOrderRef) IS NOT NULL;
        OPEN ord_cur;
        FETCH NEXT FROM ord_cur INTO @extRef, @custNo, @ccy, @promo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                BEGIN TRAN;
                SELECT @custId = CustomerId FROM dbo.Customer WHERE CustomerNo = @custNo AND Status = 'ACTIVE';

                EXEC sales.usp_CreateOrder
                     @CustomerId = @custId, @CurrencyCode = @ccy,
                     @OrderId = @orderId OUTPUT, @OrderNo = @orderNo OUTPUT;

                -- add each line
                DECLARE @sku VARCHAR(60), @qty INT, @price DECIMAL(18,4), @pid2 INT;
                DECLARE ln_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT r.Sku, TRY_CONVERT(INT, r.Qty), TRY_CONVERT(DECIMAL(18,4), r.UnitPriceText)
                      FROM stg.RawOrder r WHERE r.ExternalOrderRef = @extRef AND r.IsProcessed = 0;
                OPEN ln_cur;
                FETCH NEXT FROM ln_cur INTO @sku, @qty, @price;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SELECT @pid2 = ProductId FROM dbo.Product WHERE Sku = @sku AND Status = 'ACTIVE';
                    -- pass the imported price as an override so we honour the
                    -- source system's price rather than re-looking-up. (debated.)
                    EXEC sales.usp_AddOrderLine
                         @OrderId = @orderId, @ProductId = @pid2, @Qty = @qty, @OverridePrice = @price;
                    FETCH NEXT FROM ln_cur INTO @sku, @qty, @price;
                END
                CLOSE ln_cur; DEALLOCATE ln_cur;

                IF @promo IS NOT NULL AND LTRIM(RTRIM(@promo)) <> ''
                BEGIN
                    BEGIN TRY
                        EXEC sales.usp_ApplyPromotion @OrderId = @orderId, @PromoCode = @promo;
                    END TRY
                    BEGIN CATCH
                        -- invalid promo on import shouldn't kill the order. log + move on.
                        EXEC util.usp_LogError @ProcName = 'etl.usp_ImportRawOrders', @BatchId = @BatchId;
                    END CATCH
                END

                IF @AutoConfirm = 1
                    EXEC sales.usp_ConfirmOrder @OrderId = @orderId, @AllowBackorder = 1;

                UPDATE stg.RawOrder SET IsProcessed = 1 WHERE ExternalOrderRef = @extRef AND IsProcessed = 0;
                COMMIT;
            END TRY
            BEGIN CATCH
                IF CURSOR_STATUS('local','ln_cur') >= 0 BEGIN CLOSE ln_cur; DEALLOCATE ln_cur; END
                IF @@TRANCOUNT > 0 ROLLBACK;
                EXEC util.usp_LogError @ProcName = 'etl.usp_ImportRawOrders', @BatchId = @BatchId;
                UPDATE stg.RawOrder SET RejectReason = 'import failed - see ErrorLog'
                 WHERE ExternalOrderRef = @extRef AND IsProcessed = 0;
            END CATCH

            FETCH NEXT FROM ord_cur INTO @extRef, @custNo, @ccy, @promo;
        END
        CLOSE ord_cur; DEALLOCATE ord_cur;

        DECLARE @rejects INT;
        SELECT @rejects = COUNT(*) FROM stg.RawOrder WHERE IsProcessed = 0 AND RejectReason IS NOT NULL;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @rejects,
             @Message = CONCAT(@rejects, ' rows rejected');
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ln_cur')  >= 0 BEGIN CLOSE ln_cur;  DEALLOCATE ln_cur;  END
        IF CURSOR_STATUS('local','ord_cur') >= 0 BEGIN CLOSE ord_cur; DEALLOCATE ord_cur; END
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'etl.usp_ImportRawOrders', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
