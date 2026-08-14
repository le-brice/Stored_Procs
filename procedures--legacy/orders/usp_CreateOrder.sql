/* ============================================================
   sales.usp_CreateOrder
   Creates an empty order header for a customer and returns the new
   OrderId + OrderNo. Lines are added separately via
   sales.usp_AddOrderLine.

   Resolves default ship/bill addresses if not supplied. Picks a
   default warehouse from config key 'default.warehouse.code'.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE sales.usp_CreateOrder
    @CustomerId   INT,
    @CurrencyCode CHAR(3) = NULL,
    @ShipAddressId INT = NULL,
    @BillAddressId INT = NULL,
    @OrderId      INT OUTPUT,
    @OrderNo      VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'sales.usp_CreateOrder', @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerId = @CustomerId AND Status = 'ACTIVE')
            THROW 52001, 'Customer not found or not active', 1;

        -- currency: arg, else customer country default, else USD
        IF @CurrencyCode IS NULL
            SELECT @CurrencyCode = ISNULL(co.DefaultCurrency, 'USD')
              FROM dbo.Customer c
              LEFT JOIN ref.Country co ON co.CountryCode = c.CountryCode
             WHERE c.CustomerId = @CustomerId;
        IF @CurrencyCode IS NULL SET @CurrencyCode = 'USD';

        IF @ShipAddressId IS NULL
            SELECT TOP (1) @ShipAddressId = AddressId
              FROM dbo.CustomerAddress
             WHERE CustomerId = @CustomerId AND AddressType = 'SHIP'
             ORDER BY IsDefault DESC, AddressId;

        IF @BillAddressId IS NULL
            SET @BillAddressId = @ShipAddressId;   -- common case

        -- default warehouse
        DECLARE @whCode VARCHAR(400), @whId INT;
        EXEC util.usp_GetConfig @ParamKey = 'default.warehouse.code', @Default = 'WH01', @Value = @whCode OUTPUT;
        SELECT @whId = WarehouseId FROM inv.Warehouse WHERE WarehouseCode = @whCode;

        EXEC util.usp_NextDocNumber @Prefix = 'ORD', @DocNumber = @OrderNo OUTPUT;

        INSERT INTO sales.OrderHeader
            (OrderNo, CustomerId, OrderDate, Status, CurrencyCode,
             ShipAddressId, BillAddressId, WarehouseId)
        VALUES
            (@OrderNo, @CustomerId, SYSUTCDATETIME(), 'NEW', @CurrencyCode,
             @ShipAddressId, @BillAddressId, @whId);

        SET @OrderId = SCOPE_IDENTITY();

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = 1, @Message = @OrderNo;
    END TRY
    BEGIN CATCH
        EXEC util.usp_LogError @ProcName = 'sales.usp_CreateOrder';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
