/* ============================================================
   08_constraints_indexes.sql

   Foreign keys, check constraints, business-key uniques and the
   nonclustered indexes the procs actually rely on.

   HISTORY -- read this before you "tidy" anything in here.
   ------------------------------------------------------------
   When RetailDW was carved out of the RMS monolith in 2017 the
   tables came across but almost none of the constraints did. What
   you see inline in 01-06 is whatever the original author happened
   to type on the day. Everything else was reconstructed here in
   2019 (DBA-118) by diffing against the RMS schema and staring at
   the procs.

   Consequences of doing it that way, which are still with us:

   * Some FKs are declared WITH NOCHECK because live data already
     violated them and nobody would sign off on a cleanup. They are
     UNTRUSTED -- the optimiser ignores them and they do NOT
     guarantee integrity for existing rows, only new ones. Each one
     is commented with why. Do not "fix" these by running
     WITH CHECK CHECK CONSTRAINT; it will fail, and if you force it
     by deleting the offending rows you will break history.

   * Cross-schema FKs all live in this file rather than inline,
     because the 01-06 load order (ref -> dbo -> inv -> sales -> fin)
     can't express dbo -> sales dependencies. This file runs last,
     after every table exists.

   * A couple of relationships are deliberately NOT enforced. See
     the "deliberately absent" section at the bottom before you add
     what looks like a missing FK.
   ============================================================ */
USE RetailDW;
GO

PRINT '08_constraints_indexes: foreign keys';
GO

/* ------------------------------------------------------------
   ref.* -- currency/country lookups
   ------------------------------------------------------------ */

IF OBJECT_ID('ref.FK_Country_Ccy','F') IS NULL
ALTER TABLE ref.Country WITH CHECK
    ADD CONSTRAINT FK_Country_Ccy FOREIGN KEY (DefaultCurrency)
        REFERENCES ref.Currency(CurrencyCode);
GO

IF OBJECT_ID('ref.FK_FxRate_From','F') IS NULL
ALTER TABLE ref.FxRate WITH CHECK
    ADD CONSTRAINT FK_FxRate_From FOREIGN KEY (FromCurrency)
        REFERENCES ref.Currency(CurrencyCode);
GO

IF OBJECT_ID('ref.FK_FxRate_To','F') IS NULL
ALTER TABLE ref.FxRate WITH CHECK
    ADD CONSTRAINT FK_FxRate_To FOREIGN KEY (ToCurrency)
        REFERENCES ref.Currency(CurrencyCode);
GO

/* ------------------------------------------------------------
   dbo.* -- customer / product master
   ------------------------------------------------------------ */

/* DISABLED, and it has to be. dbo.usp_UpsertCustomer maps
   free-text country to a 2-char code, and its last-resort branch is
       WHEN LEN(@CountryRaw) = 2 THEN UPPER(@CountryRaw)
   which happily writes any two characters the feed contains,
   whether or not ref.Country has ever heard of them. So this isn't
   just a historical mess -- etl.usp_LoadCustomers produces fresh
   violations every time a feed carries a country we don't have a
   row for. WITH NOCHECK alone wouldn't be enough: it leaves
   existing rows unvalidated but still enforces new inserts, which
   would make the customer load start failing. Hence the explicit
   NOCHECK CONSTRAINT below.

   Enforcing this properly means either extending ref.Country to
   every ISO code or nulling out real customer data, and that
   argument has been going since 2019. See DATA-77. */
IF OBJECT_ID('dbo.FK_Cust_Country','F') IS NULL
BEGIN
    ALTER TABLE dbo.Customer WITH NOCHECK
        ADD CONSTRAINT FK_Cust_Country FOREIGN KEY (CountryCode)
            REFERENCES ref.Country(CountryCode);
    ALTER TABLE dbo.Customer NOCHECK CONSTRAINT FK_Cust_Country;
END
GO

/* self-referencing: survivor pointer written by dbo.usp_MergeCustomers.
   Chains are possible (A merged into B, B later merged into C) --
   see the resolver loop in etl.usp_ImportRawOrders. */
IF OBJECT_ID('dbo.FK_Cust_MergedInto','F') IS NULL
ALTER TABLE dbo.Customer WITH CHECK
    ADD CONSTRAINT FK_Cust_MergedInto FOREIGN KEY (MergedIntoId)
        REFERENCES dbo.Customer(CustomerId);
GO

IF OBJECT_ID('dbo.FK_CustAddr_Country','F') IS NULL
ALTER TABLE dbo.CustomerAddress WITH CHECK
    ADD CONSTRAINT FK_CustAddr_Country FOREIGN KEY (CountryCode)
        REFERENCES ref.Country(CountryCode);
GO

/* dbo.LoyaltyTransaction shipped with no constraints at all. */
IF OBJECT_ID('dbo.FK_LoyTxn_Acct','F') IS NULL
ALTER TABLE dbo.LoyaltyTransaction WITH CHECK
    ADD CONSTRAINT FK_LoyTxn_Acct FOREIGN KEY (LoyaltyAccountId)
        REFERENCES dbo.LoyaltyAccount(LoyaltyAccountId);
GO

/* cross-schema (dbo -> sales). Nullable: ADJUST/EXPIRE txns have no
   order behind them. This is the reason this file exists. */
IF OBJECT_ID('dbo.FK_LoyTxn_Order','F') IS NULL
ALTER TABLE dbo.LoyaltyTransaction WITH CHECK
    ADD CONSTRAINT FK_LoyTxn_Order FOREIGN KEY (OrderId)
        REFERENCES sales.OrderHeader(OrderId);
GO

/* self-referencing category hierarchy. Two levels in practice
   (department -> category); nothing enforces the depth, and nothing
   stops a cycle either -- a FK can't express that. */
IF OBJECT_ID('dbo.FK_Cat_Parent','F') IS NULL
ALTER TABLE dbo.ProductCategory WITH CHECK
    ADD CONSTRAINT FK_Cat_Parent FOREIGN KEY (ParentCategoryId)
        REFERENCES dbo.ProductCategory(CategoryId);
GO

IF OBJECT_ID('dbo.FK_Sup_Country','F') IS NULL
ALTER TABLE dbo.Supplier WITH CHECK
    ADD CONSTRAINT FK_Sup_Country FOREIGN KEY (CountryCode)
        REFERENCES ref.Country(CountryCode);
GO

IF OBJECT_ID('dbo.FK_PriceList_Ccy','F') IS NULL
ALTER TABLE dbo.PriceList WITH CHECK
    ADD CONSTRAINT FK_PriceList_Ccy FOREIGN KEY (CurrencyCode)
        REFERENCES ref.Currency(CurrencyCode);
GO

/* ------------------------------------------------------------
   inv.*
   ------------------------------------------------------------ */

IF OBJECT_ID('inv.FK_Wh_Country','F') IS NULL
ALTER TABLE inv.Warehouse WITH CHECK
    ADD CONSTRAINT FK_Wh_Country FOREIGN KEY (CountryCode)
        REFERENCES ref.Country(CountryCode);
GO

/* inv.StockMovement is the append-only ledger every inventory proc
   writes through inv.usp_PostStockMovement. It had no FKs at all,
   which is how we ended up with movements against products that
   were later hard-deleted in a 2018 cleanup. Hence NOCHECK on the
   product side; the warehouse side is clean. */
IF OBJECT_ID('inv.FK_SM_Wh','F') IS NULL
ALTER TABLE inv.StockMovement WITH CHECK
    ADD CONSTRAINT FK_SM_Wh FOREIGN KEY (WarehouseId)
        REFERENCES inv.Warehouse(WarehouseId);
GO

IF OBJECT_ID('inv.FK_SM_Prod','F') IS NULL
ALTER TABLE inv.StockMovement WITH NOCHECK
    ADD CONSTRAINT FK_SM_Prod FOREIGN KEY (ProductId)
        REFERENCES dbo.Product(ProductId);
GO

IF OBJECT_ID('inv.FK_PO_Sup','F') IS NULL
ALTER TABLE inv.PurchaseOrder WITH CHECK
    ADD CONSTRAINT FK_PO_Sup FOREIGN KEY (SupplierId)
        REFERENCES dbo.Supplier(SupplierId);
GO

IF OBJECT_ID('inv.FK_PO_Wh','F') IS NULL
ALTER TABLE inv.PurchaseOrder WITH CHECK
    ADD CONSTRAINT FK_PO_Wh FOREIGN KEY (WarehouseId)
        REFERENCES inv.Warehouse(WarehouseId);
GO

IF OBJECT_ID('inv.FK_PO_Ccy','F') IS NULL
ALTER TABLE inv.PurchaseOrder WITH CHECK
    ADD CONSTRAINT FK_PO_Ccy FOREIGN KEY (CurrencyCode)
        REFERENCES ref.Currency(CurrencyCode);
GO

IF OBJECT_ID('inv.FK_POL_Prod','F') IS NULL
ALTER TABLE inv.PurchaseOrderLine WITH CHECK
    ADD CONSTRAINT FK_POL_Prod FOREIGN KEY (ProductId)
        REFERENCES dbo.Product(ProductId);
GO

/* ------------------------------------------------------------
   sales.*
   ------------------------------------------------------------ */

IF OBJECT_ID('sales.FK_Order_Ccy','F') IS NULL
ALTER TABLE sales.OrderHeader WITH CHECK
    ADD CONSTRAINT FK_Order_Ccy FOREIGN KEY (CurrencyCode)
        REFERENCES ref.Currency(CurrencyCode);
GO

/* two FKs into the same parent -- ship-to and bill-to are the same
   kind of thing playing different roles on the order. Note neither
   is constrained to belong to the order's own customer; a FK can't
   say that, and sales.usp_CreateOrder doesn't check it either. */
IF OBJECT_ID('sales.FK_Order_ShipAddr','F') IS NULL
ALTER TABLE sales.OrderHeader WITH CHECK
    ADD CONSTRAINT FK_Order_ShipAddr FOREIGN KEY (ShipAddressId)
        REFERENCES dbo.CustomerAddress(AddressId);
GO

IF OBJECT_ID('sales.FK_Order_BillAddr','F') IS NULL
ALTER TABLE sales.OrderHeader WITH CHECK
    ADD CONSTRAINT FK_Order_BillAddr FOREIGN KEY (BillAddressId)
        REFERENCES dbo.CustomerAddress(AddressId);
GO

IF OBJECT_ID('sales.FK_Order_Promo','F') IS NULL
ALTER TABLE sales.OrderHeader WITH CHECK
    ADD CONSTRAINT FK_Order_Promo FOREIGN KEY (PromotionId)
        REFERENCES sales.Promotion(PromotionId);
GO

IF OBJECT_ID('sales.FK_Order_Wh','F') IS NULL
ALTER TABLE sales.OrderHeader WITH CHECK
    ADD CONSTRAINT FK_Order_Wh FOREIGN KEY (WarehouseId)
        REFERENCES inv.Warehouse(WarehouseId);
GO

IF OBJECT_ID('sales.FK_Pay_Ccy','F') IS NULL
ALTER TABLE sales.Payment WITH CHECK
    ADD CONSTRAINT FK_Pay_Ccy FOREIGN KEY (CurrencyCode)
        REFERENCES ref.Currency(CurrencyCode);
GO

IF OBJECT_ID('sales.FK_Ship_Wh','F') IS NULL
ALTER TABLE sales.Shipment WITH CHECK
    ADD CONSTRAINT FK_Ship_Wh FOREIGN KEY (WarehouseId)
        REFERENCES inv.Warehouse(WarehouseId);
GO

IF OBJECT_ID('sales.FK_Promo_Cat','F') IS NULL
ALTER TABLE sales.Promotion WITH CHECK
    ADD CONSTRAINT FK_Promo_Cat FOREIGN KEY (CategoryId)
        REFERENCES dbo.ProductCategory(CategoryId);
GO

/* the promo side of this table got a FK in 04; the order side
   didn't. Nobody knows why. */
IF OBJECT_ID('sales.FK_Redeem_Order','F') IS NULL
ALTER TABLE sales.PromotionRedemption WITH CHECK
    ADD CONSTRAINT FK_Redeem_Order FOREIGN KEY (OrderId)
        REFERENCES sales.OrderHeader(OrderId);
GO

/* ------------------------------------------------------------
   fin.*
   ------------------------------------------------------------ */

/* DISABLED, on purpose. Journals keep the BatchId that produced
   them forever, but util.BatchControl is trimmed to 90 days by the
   monthly maintenance job, so every journal older than a quarter is
   an orphan by design. Declared so the relationship is at least
   documented, then switched off. Re-enabling it will fail.
   Anything reading JournalEntry.BatchId must tolerate a BatchId
   with no BatchControl row. */
IF OBJECT_ID('fin.FK_JE_Batch','F') IS NULL
BEGIN
    ALTER TABLE fin.JournalEntry WITH NOCHECK
        ADD CONSTRAINT FK_JE_Batch FOREIGN KEY (BatchId)
            REFERENCES util.BatchControl(BatchId);
    ALTER TABLE fin.JournalEntry NOCHECK CONSTRAINT FK_JE_Batch;
END
GO

PRINT '08_constraints_indexes: check constraints';
GO

/* ------------------------------------------------------------
   status domains. These are the authoritative list of allowed
   values -- the inline comments in 01-06 drift, this doesn't.
   ------------------------------------------------------------ */

IF OBJECT_ID('dbo.CK_Cust_Status','C') IS NULL
ALTER TABLE dbo.Customer WITH CHECK ADD CONSTRAINT CK_Cust_Status
    CHECK (Status IN ('ACTIVE','INACTIVE','MERGED','BLOCKED'));
GO

IF OBJECT_ID('dbo.CK_Cust_NoSelfMerge','C') IS NULL
ALTER TABLE dbo.Customer WITH CHECK ADD CONSTRAINT CK_Cust_NoSelfMerge
    CHECK (MergedIntoId IS NULL OR MergedIntoId <> CustomerId);
GO

IF OBJECT_ID('dbo.CK_Prod_Status','C') IS NULL
ALTER TABLE dbo.Product WITH CHECK ADD CONSTRAINT CK_Prod_Status
    CHECK (Status IN ('ACTIVE','DISCONTINUED'));
GO

IF OBJECT_ID('dbo.CK_Loy_Tier','C') IS NULL
ALTER TABLE dbo.LoyaltyAccount WITH CHECK ADD CONSTRAINT CK_Loy_Tier
    CHECK (Tier IN ('BRONZE','SILVER','GOLD','PLATINUM'));
GO

IF OBJECT_ID('dbo.CK_LoyTxn_Type','C') IS NULL
ALTER TABLE dbo.LoyaltyTransaction WITH CHECK ADD CONSTRAINT CK_LoyTxn_Type
    CHECK (TxnType IN ('EARN','REDEEM','ADJUST','EXPIRE'));
GO

IF OBJECT_ID('sales.CK_Order_Status','C') IS NULL
ALTER TABLE sales.OrderHeader WITH CHECK ADD CONSTRAINT CK_Order_Status
    CHECK (Status IN ('NEW','CONFIRMED','PAID','PICKING','SHIPPED',
                      'COMPLETED','CANCELLED','ONHOLD'));
GO

IF OBJECT_ID('sales.CK_Pay_Status','C') IS NULL
ALTER TABLE sales.Payment WITH CHECK ADD CONSTRAINT CK_Pay_Status
    CHECK (Status IN ('AUTHORIZED','CAPTURED','REFUNDED','FAILED','VOID'));
GO

IF OBJECT_ID('sales.CK_Pay_Method','C') IS NULL
ALTER TABLE sales.Payment WITH CHECK ADD CONSTRAINT CK_Pay_Method
    CHECK (PaymentMethod IN ('CARD','PAYPAL','GIFTCARD','STORECREDIT'));
GO

IF OBJECT_ID('sales.CK_Ship_Status','C') IS NULL
ALTER TABLE sales.Shipment WITH CHECK ADD CONSTRAINT CK_Ship_Status
    CHECK (Status IN ('PENDING','SHIPPED','DELIVERED','LOST'));
GO

IF OBJECT_ID('sales.CK_Ret_Status','C') IS NULL
ALTER TABLE sales.ReturnHeader WITH CHECK ADD CONSTRAINT CK_Ret_Status
    CHECK (Status IN ('REQUESTED','APPROVED','RECEIVED','REFUNDED','REJECTED'));
GO

IF OBJECT_ID('sales.CK_Promo_Type','C') IS NULL
ALTER TABLE sales.Promotion WITH CHECK ADD CONSTRAINT CK_Promo_Type
    CHECK (PromoType IN ('PCT','AMOUNT','BOGO','FREESHIP'));
GO

IF OBJECT_ID('inv.CK_PO_Status','C') IS NULL
ALTER TABLE inv.PurchaseOrder WITH CHECK ADD CONSTRAINT CK_PO_Status
    CHECK (Status IN ('DRAFT','SENT','PARTIAL','RECEIVED','CANCELLED'));
GO

IF OBJECT_ID('inv.CK_SM_Type','C') IS NULL
ALTER TABLE inv.StockMovement WITH CHECK ADD CONSTRAINT CK_SM_Type
    CHECK (MovementType IN ('RECEIPT','SHIP','ADJUST','TRANSFER_IN',
                            'TRANSFER_OUT','RETURN'));
GO

IF OBJECT_ID('fin.CK_JE_Status','C') IS NULL
ALTER TABLE fin.JournalEntry WITH CHECK ADD CONSTRAINT CK_JE_Status
    CHECK (Status IN ('DRAFT','POSTED','REVERSED'));
GO

IF OBJECT_ID('fin.CK_JE_Source','C') IS NULL
ALTER TABLE fin.JournalEntry WITH CHECK ADD CONSTRAINT CK_JE_Source
    CHECK (Source IN ('SALES','RETURNS','SETTLEMENT','MANUAL','FX'));
GO

IF OBJECT_ID('fin.CK_Settle_Status','C') IS NULL
ALTER TABLE fin.Settlement WITH CHECK ADD CONSTRAINT CK_Settle_Status
    CHECK (Status IN ('OPEN','RECONCILED','DISCREPANCY'));
GO

IF OBJECT_ID('fin.CK_Recon_Status','C') IS NULL
ALTER TABLE fin.Reconciliation WITH CHECK ADD CONSTRAINT CK_Recon_Status
    CHECK (Status IN ('OPEN','MATCHED','UNMATCHED'));
GO

/* ------------------------------------------------------------
   sign / range rules
   ------------------------------------------------------------ */

IF OBJECT_ID('sales.CK_OL_Qty','C') IS NULL
ALTER TABLE sales.OrderLine WITH CHECK ADD CONSTRAINT CK_OL_Qty
    CHECK (Qty > 0);
GO

IF OBJECT_ID('sales.CK_OL_Amounts','C') IS NULL
ALTER TABLE sales.OrderLine WITH CHECK ADD CONSTRAINT CK_OL_Amounts
    CHECK (UnitPrice >= 0 AND LineDiscount >= 0 AND LineTax >= 0);
GO

/* TaxRate is a fraction, not a percentage. dbo.usp_GetTaxRate
   returns 0.20 for UK VAT, not 20. Getting this wrong is the
   single most common bug in this codebase. */
IF OBJECT_ID('sales.CK_OL_TaxRate','C') IS NULL
ALTER TABLE sales.OrderLine WITH CHECK ADD CONSTRAINT CK_OL_TaxRate
    CHECK (TaxRate >= 0 AND TaxRate <= 1);
GO

/* backstop for the rule sales.usp_ProcessReturn already applies
   ("p.Qty > ol.QtyShipped - ol.QtyReturned" -> reject). Note it
   deliberately does NOT bound QtyShipped by Qty: over-shipment
   happens and sales.usp_CreateShipment tops up in increments. */
IF OBJECT_ID('sales.CK_OL_Fulfilment','C') IS NULL
ALTER TABLE sales.OrderLine WITH CHECK ADD CONSTRAINT CK_OL_Fulfilment
    CHECK (QtyShipped >= 0 AND QtyReturned >= 0 AND QtyReturned <= QtyShipped);
GO

IF OBJECT_ID('sales.CK_RL_Qty','C') IS NULL
ALTER TABLE sales.ReturnLine WITH CHECK ADD CONSTRAINT CK_RL_Qty
    CHECK (Qty > 0 AND RefundAmount >= 0);
GO

IF OBJECT_ID('inv.CK_SM_Qty','C') IS NULL
ALTER TABLE inv.StockMovement WITH CHECK ADD CONSTRAINT CK_SM_Qty
    CHECK (Qty <> 0);
GO

/* DISABLED. Backorders. sales.usp_ConfirmOrder takes
   @AllowBackorder = 1 (and etl.usp_ImportRawOrders always passes
   1), which allocates stock we don't physically have and drives
   QtyOnHand negative. This happens on most nights, not just
   historically, so the constraint has to be switched off rather
   than merely untrusted -- left enforcing, it would abort the order
   import. It stays declared because it documents what the column is
   supposed to mean.

   Finance reports the negatives as zero; inventory reports them
   as-is; the two never agree. INV-204. */
IF OBJECT_ID('inv.CK_Stock_NonNeg','C') IS NULL
BEGIN
    ALTER TABLE inv.StockLevel WITH NOCHECK ADD CONSTRAINT CK_Stock_NonNeg
        CHECK (QtyOnHand >= 0 AND QtyAllocated >= 0);
    ALTER TABLE inv.StockLevel NOCHECK CONSTRAINT CK_Stock_NonNeg;
END
GO

/* over-receipt against a PO is allowed (suppliers overship and we
   take it), so there is deliberately no QtyReceived <= QtyOrdered
   bound here. */
IF OBJECT_ID('inv.CK_POL_Qty','C') IS NULL
ALTER TABLE inv.PurchaseOrderLine WITH CHECK ADD CONSTRAINT CK_POL_Qty
    CHECK (QtyOrdered > 0 AND QtyReceived >= 0 AND UnitCost >= 0);
GO

/* the fundamental journal rule: a line is a debit or a credit,
   never both. Entry-level debits = credits is enforced in code by
   fin.usp_PostJournalEntry, not here -- a CHECK can't see across
   rows. That gap is why the balance test matters. */
IF OBJECT_ID('fin.CK_JL_OneSided','C') IS NULL
ALTER TABLE fin.JournalLine WITH CHECK ADD CONSTRAINT CK_JL_OneSided
    CHECK (NOT (DebitAmount > 0 AND CreditAmount > 0));
GO

IF OBJECT_ID('fin.CK_JL_NonNeg','C') IS NULL
ALTER TABLE fin.JournalLine WITH CHECK ADD CONSTRAINT CK_JL_NonNeg
    CHECK (DebitAmount >= 0 AND CreditAmount >= 0);
GO

/* net = gross - fee, to the penny. Tolerance rather than equality
   because the fee is a rounded percentage. */
IF OBJECT_ID('fin.CK_Settle_Net','C') IS NULL
ALTER TABLE fin.Settlement WITH CHECK ADD CONSTRAINT CK_Settle_Net
    CHECK (ABS(NetAmount - (GrossAmount - FeeAmount)) <= 0.01);
GO

IF OBJECT_ID('fin.CK_Recon_Variance','C') IS NULL
ALTER TABLE fin.Reconciliation WITH CHECK ADD CONSTRAINT CK_Recon_Variance
    CHECK (ABS(Variance - (SettledAmount - ExpectedAmount)) <= 0.005);
GO

PRINT '08_constraints_indexes: business keys';
GO

/* ------------------------------------------------------------
   business keys. The identity PKs are surrogate; these are the
   grains that actually matter.
   ------------------------------------------------------------ */

IF OBJECT_ID('sales.UQ_OrderLine_LineNo','UQ') IS NULL
ALTER TABLE sales.OrderLine
    ADD CONSTRAINT UQ_OrderLine_LineNo UNIQUE (OrderId, LineNo);
GO

IF OBJECT_ID('dbo.UQ_PLI_Product','UQ') IS NULL
ALTER TABLE dbo.PriceListItem
    ADD CONSTRAINT UQ_PLI_Product UNIQUE (PriceListId, ProductId);
GO

IF OBJECT_ID('sales.UQ_ShipLine','UQ') IS NULL
ALTER TABLE sales.ShipmentLine
    ADD CONSTRAINT UQ_ShipLine UNIQUE (ShipmentId, OrderLineId);
GO

IF OBJECT_ID('sales.UQ_ReturnLine','UQ') IS NULL
ALTER TABLE sales.ReturnLine
    ADD CONSTRAINT UQ_ReturnLine UNIQUE (ReturnId, OrderLineId);
GO

IF OBJECT_ID('fin.UQ_Recon_Grain','UQ') IS NULL
ALTER TABLE fin.Reconciliation
    ADD CONSTRAINT UQ_Recon_Grain UNIQUE (ReconDate, PaymentMethod);
GO

IF OBJECT_ID('dbo.UQ_Cat_Name','UQ') IS NULL
ALTER TABLE dbo.ProductCategory
    ADD CONSTRAINT UQ_Cat_Name UNIQUE (CategoryName);
GO

/* NOTE: fin.Settlement has NO unique key on (SettlementDate,
   PaymentMethod) even though that reads like the grain.
   fin.usp_BuildSettlement can legitimately be re-run to append a
   correcting row rather than replacing the original, and finance
   wants both rows visible. fin.usp_ReconcileSettlements therefore
   SUMs over the method instead of picking a row. Anything that
   assumes one settlement row per date+method is wrong. */

PRINT '08_constraints_indexes: indexes';
GO

/* ------------------------------------------------------------
   indexes, driven by what the procs actually filter on.
   ------------------------------------------------------------ */

/* rpt.usp_BuildDailySales: WHERE CAST(OrderDate AS DATE) = @d.
   The CAST makes this non-SARGable so we get a scan anyway -- the
   index is here for the Status/Warehouse lookups that follow.
   Rewriting the predicate as a half-open range is RPT-44 and has
   been in the backlog for four years. */
IF OBJECT_ID('sales.OrderHeader') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderHeader_OrderDate'
                     AND object_id = OBJECT_ID('sales.OrderHeader'))
CREATE NONCLUSTERED INDEX IX_OrderHeader_OrderDate
    ON sales.OrderHeader (OrderDate)
    INCLUDE (Status, WarehouseId, CurrencyCode);
GO

/* fin.usp_GenerateSalesJournal keys off ModifiedUtc, not OrderDate.
   That is not a typo -- see the header comment in that proc. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderHeader_Modified'
                 AND object_id = OBJECT_ID('sales.OrderHeader'))
CREATE NONCLUSTERED INDEX IX_OrderHeader_Modified
    ON sales.OrderHeader (ModifiedUtc, Status)
    INCLUDE (CurrencyCode, SubTotal, DiscountTotal, TaxTotal, GrandTotal);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderHeader_Cust'
                 AND object_id = OBJECT_ID('sales.OrderHeader'))
CREATE NONCLUSTERED INDEX IX_OrderHeader_Cust
    ON sales.OrderHeader (CustomerId, Status) INCLUDE (OrderDate, GrandTotal);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderLine_Order'
                 AND object_id = OBJECT_ID('sales.OrderLine'))
CREATE NONCLUSTERED INDEX IX_OrderLine_Order
    ON sales.OrderLine (OrderId) INCLUDE (ProductId, Qty, UnitPrice, LineDiscount, LineTax);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderLine_Product'
                 AND object_id = OBJECT_ID('sales.OrderLine'))
CREATE NONCLUSTERED INDEX IX_OrderLine_Product
    ON sales.OrderLine (ProductId) INCLUDE (Qty, UnitPrice);
GO

/* fin.usp_ReconcileSettlements: CAST(ProcessedUtc AS DATE) + Status */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payment_Processed'
                 AND object_id = OBJECT_ID('sales.Payment'))
CREATE NONCLUSTERED INDEX IX_Payment_Processed
    ON sales.Payment (ProcessedUtc, Status) INCLUDE (PaymentMethod, Amount, CurrencyCode);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payment_Order'
                 AND object_id = OBJECT_ID('sales.Payment'))
CREATE NONCLUSTERED INDEX IX_Payment_Order ON sales.Payment (OrderId);
GO

/* COGS pull in the sales journal */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StockMovement_TypeDate'
                 AND object_id = OBJECT_ID('inv.StockMovement'))
CREATE NONCLUSTERED INDEX IX_StockMovement_TypeDate
    ON inv.StockMovement (MovementType, CreatedUtc)
    INCLUDE (ProductId, WarehouseId, Qty, UnitCost);
GO

/* the polymorphic lookup -- (RefType, RefId) is how every proc
   finds the movements behind an order/PO/return. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StockMovement_Ref'
                 AND object_id = OBJECT_ID('inv.StockMovement'))
CREATE NONCLUSTERED INDEX IX_StockMovement_Ref
    ON inv.StockMovement (RefType, RefId) INCLUDE (MovementType, Qty);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_StockMovement_WhProd'
                 AND object_id = OBJECT_ID('inv.StockMovement'))
CREATE NONCLUSTERED INDEX IX_StockMovement_WhProd
    ON inv.StockMovement (WarehouseId, ProductId, CreatedUtc);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalEntry_Date'
                 AND object_id = OBJECT_ID('fin.JournalEntry'))
CREATE NONCLUSTERED INDEX IX_JournalEntry_Date
    ON fin.JournalEntry (EntryDate, Source) INCLUDE (Status, JournalNo, BatchId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalLine_Journal'
                 AND object_id = OBJECT_ID('fin.JournalLine'))
CREATE NONCLUSTERED INDEX IX_JournalLine_Journal
    ON fin.JournalLine (JournalId) INCLUDE (GLAccountId, DebitAmount, CreditAmount);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Settlement_Date'
                 AND object_id = OBJECT_ID('fin.Settlement'))
CREATE NONCLUSTERED INDEX IX_Settlement_Date
    ON fin.Settlement (SettlementDate, PaymentMethod) INCLUDE (GrossAmount, FeeAmount, NetAmount, Status);
GO

/* dbo.usp_ConvertCurrency's exact access path: pair + newest rate
   on or before a date. Descending on RateDate so TOP (1) is a seek. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FxRate_Lookup'
                 AND object_id = OBJECT_ID('ref.FxRate'))
CREATE NONCLUSTERED INDEX IX_FxRate_Lookup
    ON ref.FxRate (FromCurrency, ToCurrency, RateDate DESC) INCLUDE (Rate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_Email'
                 AND object_id = OBJECT_ID('dbo.Customer'))
CREATE NONCLUSTERED INDEX IX_Customer_Email
    ON dbo.Customer (Email) INCLUDE (Status, MergedIntoId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LoyTxn_Acct'
                 AND object_id = OBJECT_ID('dbo.LoyaltyTransaction'))
CREATE NONCLUSTERED INDEX IX_LoyTxn_Acct
    ON dbo.LoyaltyTransaction (LoyaltyAccountId, CreatedUtc) INCLUDE (TxnType, Points);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ReturnHeader_Order'
                 AND object_id = OBJECT_ID('sales.ReturnHeader'))
CREATE NONCLUSTERED INDEX IX_ReturnHeader_Order
    ON sales.ReturnHeader (OrderId) INCLUDE (Status, RefundAmount, CreatedUtc);
GO

/* ------------------------------------------------------------
   filtered indexes on the landing tables. Every ETL proc opens
   with WHERE IsProcessed = 0, and the staging tables are never
   trimmed, so without these the nightly batch scans years of
   already-processed rows to find last night's few hundred.
   ------------------------------------------------------------ */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RawOrder_Pending'
                 AND object_id = OBJECT_ID('stg.RawOrder'))
CREATE NONCLUSTERED INDEX IX_RawOrder_Pending
    ON stg.RawOrder (ExternalOrderRef) INCLUDE (CustomerNo, Sku, Qty, UnitPriceText, RejectReason)
    WHERE IsProcessed = 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RawCustomer_Pending'
                 AND object_id = OBJECT_ID('stg.RawCustomer'))
CREATE NONCLUSTERED INDEX IX_RawCustomer_Pending
    ON stg.RawCustomer (RowId) WHERE IsProcessed = 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RawProduct_Pending'
                 AND object_id = OBJECT_ID('stg.RawProduct'))
CREATE NONCLUSTERED INDEX IX_RawProduct_Pending
    ON stg.RawProduct (RowId) WHERE IsProcessed = 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RawFxRate_Pending'
                 AND object_id = OBJECT_ID('stg.RawFxRate'))
CREATE NONCLUSTERED INDEX IX_RawFxRate_Pending
    ON stg.RawFxRate (RowId) WHERE IsProcessed = 0;
GO

/* ============================================================
   DELIBERATELY ABSENT -- do not "complete" these.
   ============================================================

   stg.*  no constraints of any kind. It is a landing zone; bad
          rows are supposed to land so the ETL can stamp
          RejectReason and a human can look at them. A FK here
          would fail the bulk load instead, which is worse.

   rpt.*  no FKs. The report builders DELETE the target date and
          re-INSERT, and the ids they write were already validated
          upstream. FKs would only slow the rebuild. The reporting
          tables also intentionally carry CategoryId = 0 for
          uncategorised products (see the ISNULL in
          rpt.usp_BuildDailySales), and 0 is not a real category --
          a FK to dbo.ProductCategory would reject every one of
          those rows.

   inv.StockMovement.RefId -> ???
          Polymorphic. RefType discriminates ORDER | PO | RETURN |
          MANUAL and RefId points into sales.OrderHeader,
          inv.PurchaseOrder or sales.ReturnHeader accordingly.
          MANUAL rows have a RefId of NULL or, in a handful of 2018
          rows, a free-text ticket number that was shoved into the
          column before it was typed as INT. No single FK can
          express this. Resolving it needs the CASE in
          IX_StockMovement_Ref's callers.

   fin.Settlement / fin.Reconciliation -> sales.Payment
          These reconcile at (date, method) aggregate grain, not
          row grain. There is no payment-level settlement id coming
          back from the processor, which is the entire reason
          fin.usp_ReconcileSettlements exists and has a tolerance.

   util.ProcLog.BatchId / util.ErrorLog.BatchId -> util.BatchControl
          Not enforced, on purpose. Logging must never be the thing
          that fails a proc. Plenty of procs are run by hand with
          @BatchId = NULL, and util.usp_LogError has to be able to
          write from inside a CATCH block even when the batch row
          was rolled back.
   ============================================================ */

PRINT '08_constraints_indexes: done';
GO
