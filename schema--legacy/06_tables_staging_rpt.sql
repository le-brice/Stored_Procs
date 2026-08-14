/* ============================================================
   06_tables_staging_rpt.sql
   Staging (loaded by SSIS) + reporting output tables.
   ============================================================ */
USE RetailDW;
GO

/* ---------- staging (raw landing zone) ---------- */

IF OBJECT_ID('stg.RawCustomer') IS NULL
CREATE TABLE stg.RawCustomer (
    RowId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerNo    VARCHAR(50)   NULL,
    FirstName     VARCHAR(100)  NULL,
    LastName      VARCHAR(100)  NULL,
    Email         VARCHAR(200)  NULL,
    Phone         VARCHAR(60)   NULL,
    Country       VARCHAR(60)   NULL,   -- free text, needs mapping to CountryCode
    SourceFile    VARCHAR(200)  NULL,
    LoadedUtc     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    IsProcessed   BIT           NOT NULL DEFAULT 0
);
GO

IF OBJECT_ID('stg.RawProduct') IS NULL
CREATE TABLE stg.RawProduct (
    RowId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    Sku           VARCHAR(60)   NULL,
    ProductName   VARCHAR(300)  NULL,
    CategoryName  VARCHAR(120)  NULL,
    SupplierName  VARCHAR(200)  NULL,
    UnitCost      VARCHAR(40)   NULL,    -- arrives as text, ugh
    ListPrice     VARCHAR(40)   NULL,
    LoadedUtc     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    IsProcessed   BIT           NOT NULL DEFAULT 0
);
GO

IF OBJECT_ID('stg.RawOrder') IS NULL
CREATE TABLE stg.RawOrder (
    RowId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    ExternalOrderRef VARCHAR(60) NULL,
    CustomerNo    VARCHAR(50)   NULL,
    OrderDateText VARCHAR(40)   NULL,
    Sku           VARCHAR(60)   NULL,
    Qty           VARCHAR(20)   NULL,
    UnitPriceText VARCHAR(40)   NULL,
    PromoCode     VARCHAR(40)   NULL,
    CurrencyCode  CHAR(3)       NULL,
    SourceSystem  VARCHAR(40)   NULL,
    LoadedUtc     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    IsProcessed   BIT           NOT NULL DEFAULT 0,
    RejectReason  VARCHAR(400)  NULL
);
GO

IF OBJECT_ID('stg.RawFxRate') IS NULL
CREATE TABLE stg.RawFxRate (
    RowId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    FromCurrency  CHAR(3)       NULL,
    ToCurrency    CHAR(3)       NULL,
    RateDateText  VARCHAR(40)   NULL,
    RateText      VARCHAR(40)   NULL,
    LoadedUtc     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    IsProcessed   BIT           NOT NULL DEFAULT 0
);
GO

/* ---------- reporting outputs ---------- */

IF OBJECT_ID('rpt.DailySalesSummary') IS NULL
CREATE TABLE rpt.DailySalesSummary (
    SummaryDate   DATE          NOT NULL,
    WarehouseId   INT           NOT NULL,
    CategoryId    INT           NOT NULL,
    OrderCount    INT           NOT NULL,
    UnitsSold     INT           NOT NULL,
    GrossRevenue  DECIMAL(18,4) NOT NULL,
    DiscountTotal DECIMAL(18,4) NOT NULL,
    NetRevenue    DECIMAL(18,4) NOT NULL,
    EstMargin     DECIMAL(18,4) NULL,
    BuiltUtc      DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_DailySalesSummary PRIMARY KEY (SummaryDate, WarehouseId, CategoryId)
);
GO

IF OBJECT_ID('rpt.CustomerLtv') IS NULL
CREATE TABLE rpt.CustomerLtv (
    CustomerId    INT           NOT NULL PRIMARY KEY,
    FirstOrderDate DATE         NULL,
    LastOrderDate DATE          NULL,
    OrderCount    INT           NOT NULL DEFAULT 0,
    TotalNetSpend DECIMAL(18,4) NOT NULL DEFAULT 0,
    AvgOrderValue DECIMAL(18,4) NOT NULL DEFAULT 0,
    LtvScore      DECIMAL(10,2) NULL,
    Segment       VARCHAR(20)   NULL,   -- VIP|REGULAR|LAPSED|NEW
    BuiltUtc      DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('rpt.InventorySnapshot') IS NULL
CREATE TABLE rpt.InventorySnapshot (
    SnapshotDate  DATE          NOT NULL,
    WarehouseId   INT           NOT NULL,
    ProductId     INT           NOT NULL,
    QtyOnHand     INT           NOT NULL,
    QtyAllocated  INT           NOT NULL,
    QtyAvailable  INT           NOT NULL,
    StockValue    DECIMAL(18,4) NOT NULL,
    BelowReorder  BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_InvSnapshot PRIMARY KEY (SnapshotDate, WarehouseId, ProductId)
);
GO
