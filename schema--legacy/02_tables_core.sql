/* ============================================================
   02_tables_core.sql
   Customer + product master (live in dbo, RMS legacy).
   ============================================================ */
USE RetailDW;
GO

IF OBJECT_ID('dbo.Customer') IS NULL
CREATE TABLE dbo.Customer (
    CustomerId    INT IDENTITY(1,1) PRIMARY KEY,
    CustomerNo    VARCHAR(20)   NOT NULL UNIQUE,     -- external/business key
    FirstName     VARCHAR(80)   NULL,
    LastName      VARCHAR(80)   NULL,
    Email         VARCHAR(200)  NULL,
    Phone         VARCHAR(40)   NULL,
    CountryCode   CHAR(2)       NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE|INACTIVE|MERGED|BLOCKED
    MergedIntoId  INT           NULL,    -- set when this row was merged into another
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedUtc   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dbo.CustomerAddress') IS NULL
CREATE TABLE dbo.CustomerAddress (
    AddressId     INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId    INT           NOT NULL,
    AddressType   VARCHAR(10)   NOT NULL DEFAULT 'SHIP',   -- SHIP|BILL
    Line1         VARCHAR(200)  NULL,
    Line2         VARCHAR(200)  NULL,
    City          VARCHAR(100)  NULL,
    PostCode      VARCHAR(20)   NULL,
    CountryCode   CHAR(2)       NULL,
    IsDefault     BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_CustAddr_Cust FOREIGN KEY (CustomerId) REFERENCES dbo.Customer(CustomerId)
);
GO

IF OBJECT_ID('dbo.LoyaltyAccount') IS NULL
CREATE TABLE dbo.LoyaltyAccount (
    LoyaltyAccountId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId    INT           NOT NULL UNIQUE,
    Tier          VARCHAR(20)   NOT NULL DEFAULT 'BRONZE',  -- BRONZE|SILVER|GOLD|PLATINUM
    PointsBalance INT           NOT NULL DEFAULT 0,
    LifetimePoints INT          NOT NULL DEFAULT 0,
    EnrolledUtc   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Loyalty_Cust FOREIGN KEY (CustomerId) REFERENCES dbo.Customer(CustomerId)
);
GO

IF OBJECT_ID('dbo.LoyaltyTransaction') IS NULL
CREATE TABLE dbo.LoyaltyTransaction (
    LoyaltyTxnId  BIGINT IDENTITY(1,1) PRIMARY KEY,
    LoyaltyAccountId INT        NOT NULL,
    TxnType       VARCHAR(20)   NOT NULL,    -- EARN|REDEEM|ADJUST|EXPIRE
    Points        INT           NOT NULL,    -- signed
    OrderId       INT           NULL,
    Note          VARCHAR(200)  NULL,
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('dbo.ProductCategory') IS NULL
CREATE TABLE dbo.ProductCategory (
    CategoryId    INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName  VARCHAR(100)  NOT NULL,
    ParentCategoryId INT        NULL,
    DefaultMarginPct DECIMAL(6,3) NULL
);
GO

IF OBJECT_ID('dbo.Supplier') IS NULL
CREATE TABLE dbo.Supplier (
    SupplierId    INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName  VARCHAR(150)  NOT NULL,
    CountryCode   CHAR(2)       NULL,
    LeadTimeDays  INT           NOT NULL DEFAULT 7,
    IsActive      BIT           NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('dbo.Product') IS NULL
CREATE TABLE dbo.Product (
    ProductId     INT IDENTITY(1,1) PRIMARY KEY,
    Sku           VARCHAR(40)   NOT NULL UNIQUE,
    ProductName   VARCHAR(200)  NOT NULL,
    CategoryId    INT           NULL,
    SupplierId    INT           NULL,
    UnitCost      DECIMAL(18,4) NULL,         -- base/standard cost
    ListPrice     DECIMAL(18,4) NULL,
    Weight_g      INT           NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE|DISCONTINUED
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Product_Cat FOREIGN KEY (CategoryId) REFERENCES dbo.ProductCategory(CategoryId),
    CONSTRAINT FK_Product_Sup FOREIGN KEY (SupplierId) REFERENCES dbo.Supplier(SupplierId)
);
GO

-- price lists (currency-specific). Effective-dated, sort of.
IF OBJECT_ID('dbo.PriceList') IS NULL
CREATE TABLE dbo.PriceList (
    PriceListId   INT IDENTITY(1,1) PRIMARY KEY,
    PriceListName VARCHAR(100)  NOT NULL,
    CurrencyCode  CHAR(3)       NOT NULL,
    EffectiveFrom DATE          NOT NULL,
    EffectiveTo   DATE          NULL,
    IsActive      BIT           NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('dbo.PriceListItem') IS NULL
CREATE TABLE dbo.PriceListItem (
    PriceListItemId INT IDENTITY(1,1) PRIMARY KEY,
    PriceListId   INT           NOT NULL,
    ProductId     INT           NOT NULL,
    UnitPrice     DECIMAL(18,4) NOT NULL,
    CONSTRAINT FK_PLI_PL  FOREIGN KEY (PriceListId) REFERENCES dbo.PriceList(PriceListId),
    CONSTRAINT FK_PLI_Prod FOREIGN KEY (ProductId)  REFERENCES dbo.Product(ProductId)
);
GO
