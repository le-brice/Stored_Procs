/* ============================================================
   03_tables_inventory.sql
   Warehouses, stock, movements, purchase orders.
   ============================================================ */
USE RetailDW;
GO

IF OBJECT_ID('inv.Warehouse') IS NULL
CREATE TABLE inv.Warehouse (
    WarehouseId   INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseCode VARCHAR(10)   NOT NULL UNIQUE,
    WarehouseName VARCHAR(100)  NOT NULL,
    CountryCode   CHAR(2)       NULL,
    IsActive      BIT           NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('inv.StockLevel') IS NULL
CREATE TABLE inv.StockLevel (
    WarehouseId   INT           NOT NULL,
    ProductId     INT           NOT NULL,
    QtyOnHand     INT           NOT NULL DEFAULT 0,
    QtyAllocated  INT           NOT NULL DEFAULT 0,   -- reserved by open orders
    QtyOnOrder    INT           NOT NULL DEFAULT 0,   -- inbound from POs
    ReorderPoint  INT           NULL,
    ReorderQty    INT           NULL,
    LastCountedUtc DATETIME2(3) NULL,
    CONSTRAINT PK_StockLevel PRIMARY KEY (WarehouseId, ProductId),
    CONSTRAINT FK_Stock_Wh   FOREIGN KEY (WarehouseId) REFERENCES inv.Warehouse(WarehouseId),
    CONSTRAINT FK_Stock_Prod FOREIGN KEY (ProductId)   REFERENCES dbo.Product(ProductId)
);
GO

IF OBJECT_ID('inv.StockMovement') IS NULL
CREATE TABLE inv.StockMovement (
    MovementId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    WarehouseId   INT           NOT NULL,
    ProductId     INT           NOT NULL,
    MovementType  VARCHAR(20)   NOT NULL,  -- RECEIPT|SHIP|ADJUST|TRANSFER_IN|TRANSFER_OUT|RETURN
    Qty           INT           NOT NULL,  -- signed
    RefType       VARCHAR(20)   NULL,      -- ORDER|PO|RETURN|MANUAL
    RefId         INT           NULL,
    UnitCost      DECIMAL(18,4) NULL,
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy     SYSNAME       NOT NULL DEFAULT SUSER_SNAME()
);
GO

IF OBJECT_ID('inv.PurchaseOrder') IS NULL
CREATE TABLE inv.PurchaseOrder (
    PurchaseOrderId INT IDENTITY(1,1) PRIMARY KEY,
    PoNumber      VARCHAR(20)   NOT NULL UNIQUE,
    SupplierId    INT           NOT NULL,
    WarehouseId   INT           NOT NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'DRAFT',  -- DRAFT|SENT|PARTIAL|RECEIVED|CANCELLED
    OrderDate     DATE          NOT NULL DEFAULT CAST(SYSUTCDATETIME() AS DATE),
    ExpectedDate  DATE          NULL,
    CurrencyCode  CHAR(3)       NOT NULL DEFAULT 'USD',
    TotalCost     DECIMAL(18,4) NULL,
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('inv.PurchaseOrderLine') IS NULL
CREATE TABLE inv.PurchaseOrderLine (
    PoLineId      INT IDENTITY(1,1) PRIMARY KEY,
    PurchaseOrderId INT         NOT NULL,
    ProductId     INT           NOT NULL,
    QtyOrdered    INT           NOT NULL,
    QtyReceived   INT           NOT NULL DEFAULT 0,
    UnitCost      DECIMAL(18,4) NOT NULL,
    CONSTRAINT FK_POL_PO FOREIGN KEY (PurchaseOrderId) REFERENCES inv.PurchaseOrder(PurchaseOrderId)
);
GO
