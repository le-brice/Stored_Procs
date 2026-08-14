/* ============================================================
   04_tables_sales.sql
   Orders, lines, payments, shipments, returns, promotions.
   ============================================================ */
USE RetailDW;
GO

IF OBJECT_ID('sales.Promotion') IS NULL
CREATE TABLE sales.Promotion (
    PromotionId   INT IDENTITY(1,1) PRIMARY KEY,
    PromoCode     VARCHAR(30)   NOT NULL UNIQUE,
    Description   VARCHAR(200)  NULL,
    PromoType     VARCHAR(20)   NOT NULL,   -- PCT|AMOUNT|BOGO|FREESHIP
    DiscountPct   DECIMAL(6,3)  NULL,       -- for PCT
    DiscountAmt   DECIMAL(18,4) NULL,       -- for AMOUNT
    MinSpend      DECIMAL(18,4) NULL,
    CategoryId    INT           NULL,       -- restrict to a category, optional
    EffectiveFrom DATE          NOT NULL,
    EffectiveTo   DATE          NULL,
    MaxRedemptions INT          NULL,
    TimesRedeemed INT           NOT NULL DEFAULT 0,
    IsActive      BIT           NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('sales.OrderHeader') IS NULL
CREATE TABLE sales.OrderHeader (
    OrderId       INT IDENTITY(1,1) PRIMARY KEY,
    OrderNo       VARCHAR(20)   NOT NULL UNIQUE,
    CustomerId    INT           NOT NULL,
    OrderDate     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    Status        VARCHAR(20)   NOT NULL DEFAULT 'NEW',
        -- NEW|CONFIRMED|PAID|PICKING|SHIPPED|COMPLETED|CANCELLED|ONHOLD
    CurrencyCode  CHAR(3)       NOT NULL DEFAULT 'USD',
    ShipAddressId INT           NULL,
    BillAddressId INT           NULL,
    PromotionId   INT           NULL,
    SubTotal      DECIMAL(18,4) NOT NULL DEFAULT 0,
    DiscountTotal DECIMAL(18,4) NOT NULL DEFAULT 0,
    TaxTotal      DECIMAL(18,4) NOT NULL DEFAULT 0,
    ShippingTotal DECIMAL(18,4) NOT NULL DEFAULT 0,
    GrandTotal    DECIMAL(18,4) NOT NULL DEFAULT 0,
    PaidAmount    DECIMAL(18,4) NOT NULL DEFAULT 0,
    WarehouseId   INT           NULL,
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedUtc   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Order_Cust FOREIGN KEY (CustomerId) REFERENCES dbo.Customer(CustomerId)
);
GO

IF OBJECT_ID('sales.OrderLine') IS NULL
CREATE TABLE sales.OrderLine (
    OrderLineId   INT IDENTITY(1,1) PRIMARY KEY,
    OrderId       INT           NOT NULL,
    LineNo        INT           NOT NULL,
    ProductId     INT           NOT NULL,
    Qty           INT           NOT NULL,
    UnitPrice     DECIMAL(18,4) NOT NULL,
    LineDiscount  DECIMAL(18,4) NOT NULL DEFAULT 0,
    TaxRate       DECIMAL(6,4)  NOT NULL DEFAULT 0,
    LineTax       DECIMAL(18,4) NOT NULL DEFAULT 0,
    LineTotal     DECIMAL(18,4) NOT NULL DEFAULT 0,
    QtyShipped    INT           NOT NULL DEFAULT 0,
    QtyReturned   INT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_OL_Order FOREIGN KEY (OrderId) REFERENCES sales.OrderHeader(OrderId),
    CONSTRAINT FK_OL_Prod  FOREIGN KEY (ProductId) REFERENCES dbo.Product(ProductId)
);
GO

IF OBJECT_ID('sales.Payment') IS NULL
CREATE TABLE sales.Payment (
    PaymentId     INT IDENTITY(1,1) PRIMARY KEY,
    OrderId       INT           NOT NULL,
    PaymentMethod VARCHAR(20)   NOT NULL,   -- CARD|PAYPAL|GIFTCARD|STORECREDIT
    Amount        DECIMAL(18,4) NOT NULL,
    CurrencyCode  CHAR(3)       NOT NULL DEFAULT 'USD',
    Status        VARCHAR(20)   NOT NULL DEFAULT 'AUTHORIZED', -- AUTHORIZED|CAPTURED|REFUNDED|FAILED|VOID
    AuthCode      VARCHAR(40)   NULL,
    ProcessedUtc  DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Pay_Order FOREIGN KEY (OrderId) REFERENCES sales.OrderHeader(OrderId)
);
GO

IF OBJECT_ID('sales.Shipment') IS NULL
CREATE TABLE sales.Shipment (
    ShipmentId    INT IDENTITY(1,1) PRIMARY KEY,
    OrderId       INT           NOT NULL,
    WarehouseId   INT           NOT NULL,
    Carrier       VARCHAR(40)   NULL,
    TrackingNo    VARCHAR(60)   NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'PENDING', -- PENDING|SHIPPED|DELIVERED|LOST
    ShippedUtc    DATETIME2(3)  NULL,
    CONSTRAINT FK_Ship_Order FOREIGN KEY (OrderId) REFERENCES sales.OrderHeader(OrderId)
);
GO

IF OBJECT_ID('sales.ShipmentLine') IS NULL
CREATE TABLE sales.ShipmentLine (
    ShipmentLineId INT IDENTITY(1,1) PRIMARY KEY,
    ShipmentId    INT           NOT NULL,
    OrderLineId   INT           NOT NULL,
    Qty           INT           NOT NULL,
    CONSTRAINT FK_SL_Ship FOREIGN KEY (ShipmentId) REFERENCES sales.Shipment(ShipmentId),
    CONSTRAINT FK_SL_OL   FOREIGN KEY (OrderLineId) REFERENCES sales.OrderLine(OrderLineId)
);
GO

IF OBJECT_ID('sales.ReturnHeader') IS NULL
CREATE TABLE sales.ReturnHeader (
    ReturnId      INT IDENTITY(1,1) PRIMARY KEY,
    RmaNumber     VARCHAR(20)   NOT NULL UNIQUE,
    OrderId       INT           NOT NULL,
    Reason        VARCHAR(40)   NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'REQUESTED', -- REQUESTED|APPROVED|RECEIVED|REFUNDED|REJECTED
    RefundAmount  DECIMAL(18,4) NOT NULL DEFAULT 0,
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Ret_Order FOREIGN KEY (OrderId) REFERENCES sales.OrderHeader(OrderId)
);
GO

IF OBJECT_ID('sales.ReturnLine') IS NULL
CREATE TABLE sales.ReturnLine (
    ReturnLineId  INT IDENTITY(1,1) PRIMARY KEY,
    ReturnId      INT           NOT NULL,
    OrderLineId   INT           NOT NULL,
    Qty           INT           NOT NULL,
    RefundAmount  DECIMAL(18,4) NOT NULL DEFAULT 0,
    Restock       BIT           NOT NULL DEFAULT 1,
    CONSTRAINT FK_RL_Ret FOREIGN KEY (ReturnId) REFERENCES sales.ReturnHeader(ReturnId),
    CONSTRAINT FK_RL_OL  FOREIGN KEY (OrderLineId) REFERENCES sales.OrderLine(OrderLineId)
);
GO

IF OBJECT_ID('sales.PromotionRedemption') IS NULL
CREATE TABLE sales.PromotionRedemption (
    RedemptionId  INT IDENTITY(1,1) PRIMARY KEY,
    PromotionId   INT           NOT NULL,
    OrderId       INT           NOT NULL,
    DiscountApplied DECIMAL(18,4) NOT NULL,
    RedeemedUtc   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Redeem_Promo FOREIGN KEY (PromotionId) REFERENCES sales.Promotion(PromotionId)
);
GO
