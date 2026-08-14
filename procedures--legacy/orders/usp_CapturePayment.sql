/* ============================================================
   sales.usp_CapturePayment
   Records a captured payment against an order. Converts the payment
   amount into the order currency if they differ (gift cards are
   always USD, for instance). Bumps OrderHeader.PaidAmount and, when
   fully paid, transitions CONFIRMED -> PAID.

   Does not talk to a real payment gateway -- that's the app's job.
   This just books the result.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_CapturePayment
    @OrderId       INT,
    @PaymentMethod VARCHAR(20),
    @Amount        DECIMAL(18,4),
    @CurrencyCode  CHAR(3) = NULL,
    @AuthCode      VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_CapturePayment', @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        DECLARE @orderCcy CHAR(3), @grand DECIMAL(18,4), @paid DECIMAL(18,4), @status VARCHAR(20);
        SELECT @orderCcy = CurrencyCode, @grand = GrandTotal, @paid = PaidAmount, @status = Status
          FROM sales.OrderHeader WHERE OrderId = @OrderId;

        IF @status IS NULL THROW 52030, 'Order not found', 1;
        IF @status IN ('CANCELLED','COMPLETED') THROW 52031, 'Cannot pay a closed order', 1;

        IF @CurrencyCode IS NULL SET @CurrencyCode = @orderCcy;

        DECLARE @amountInOrderCcy DECIMAL(18,4) = @Amount;
        IF @CurrencyCode <> @orderCcy
            EXEC dbo.usp_ConvertCurrency
                 @Amount = @Amount, @FromCurrency = @CurrencyCode,
                 @ToCurrency = @orderCcy, @Result = @amountInOrderCcy OUTPUT;

        INSERT INTO sales.Payment (OrderId, PaymentMethod, Amount, CurrencyCode, Status, AuthCode)
        VALUES (@OrderId, @PaymentMethod, @Amount, @CurrencyCode, 'CAPTURED', @AuthCode);

        SET @paid = @paid + @amountInOrderCcy;

        UPDATE sales.OrderHeader
           SET PaidAmount = @paid,
               Status = CASE WHEN @paid >= @grand AND Status = 'CONFIRMED' THEN 'PAID' ELSE Status END,
               ModifiedUtc = SYSUTCDATETIME()
         WHERE OrderId = @OrderId;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = @PaymentMethod;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'sales.usp_CapturePayment';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
