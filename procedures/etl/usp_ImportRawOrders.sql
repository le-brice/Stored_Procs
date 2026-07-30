/* ============================================================
   etl.usp_ImportRawOrders
   The big one.

   Turns flat stg.RawOrder rows (one row per order LINE, grouped by
   ExternalOrderRef) into real orders by driving the same procs the
   app uses: sales.usp_CreateOrder, sales.usp_AddOrderLine,
   sales.usp_ApplyPromotion, sales.usp_ConfirmOrder.

   This is deliberately built on the OLTP procs so imported orders
   go through identical pricing/tax/loyalty logic. It is slow and
   cursor-heavy and that is the trade we made in 2017. Rewriting it
   set-based means reimplementing pricing, tax, promotion and
   loyalty in a second place, and the last person to propose that
   left before finishing.

   ------------------------------------------------------------
   SHAPE OF THE THING
   ------------------------------------------------------------
     pass 1  structural validation   -- can the row be parsed at all
     pass 2  referential validation  -- do the keys resolve
     pass 3  business validation     -- is the row sane
     dedupe                          -- collapse repeated refs
     resolve                         -- follow merged-customer chains
     import                          -- the nested cursors
     reconcile                       -- did we import what arrived
     watermark                       -- remember how far we got

   An order is imported only if ALL of its lines survive all three
   validation passes. Partial orders are worse than no order: the
   totals go out to finance and the missing lines turn up as a
   reconciliation variance three weeks later.

   ------------------------------------------------------------
   REJECTS
   ------------------------------------------------------------
   Rejected rows get RejectReason stamped and are left with
   IsProcessed = 0 for a human to look at. They are NOT deleted and
   they are NOT retried automatically -- pass @ReprocessRejects = 1
   to clear the stamps and have another go, which is what you want
   after fixing reference data and nothing else.

   Severity is tracked internally (1 = structural, 2 = referential,
   3 = business) but stg.RawOrder has nowhere to put it, so it ends
   up prefixed into the reason text. Adding a Severity column has
   been on the list since 2019.

   ------------------------------------------------------------
   THINGS THAT WILL SURPRISE YOU
   ------------------------------------------------------------
   * sales.usp_AddOrderLine MERGES a repeated product into the
     existing line (Qty = Qty + @Qty). A feed that lists the same
     SKU twice in one order therefore produces ONE line with the
     summed quantity, at the price of whichever row was processed
     first. The second row's price is discarded silently. This is
     load-bearing behaviour for at least one source system that
     splits lines by promotion.

   * The imported price is passed as @OverridePrice, so the feed's
     price wins over the price list. That was debated for a long
     time. The argument that won: the source system already told
     the customer a price and we are not going to change it after
     the fact. The consequence: a bad feed price becomes a real
     order at that price, which is why pass 3 checks it against
     dbo.Product.ListPrice with a tolerance.

   * sales.usp_CreateOrder always picks the warehouse from config
     key 'default.warehouse.code' and ignores anything we know
     about where the order should ship from. Every imported order
     is therefore WH01 regardless of the customer's country, which
     is why the intercompany pass in fin.usp_GenerateSalesJournal
     sees so much traffic.

   * @AutoConfirm = 1 passes @AllowBackorder = 1 to
     sales.usp_ConfirmOrder, which will allocate stock we do not
     have and push inv.StockLevel.QtyOnHand negative. That is the
     reason CK_Stock_NonNeg is disabled in
     schema/08_constraints_indexes.sql.

   Assumes etl.usp_LoadCustomers + etl.usp_LoadProducts already ran
   this batch (it resolves CustomerNo / Sku to ids and rejects if
   missing). It checks, and warns, but does not enforce -- running
   it standalone against yesterday's masters is a legitimate
   recovery move.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_ImportRawOrders
    @BatchId           UNIQUEIDENTIFIER = NULL,
    @AutoConfirm       BIT              = 1,
    @SourceSystem      VARCHAR(40)      = NULL,   -- NULL = all systems
    @MaxOrders         INT              = NULL,   -- NULL -> config import.max.orders
    @ReprocessRejects  BIT              = 0,
    @ContinueOnError   BIT              = 1,
    @DryRun            BIT              = 0,
    @DebugLevel        TINYINT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_ImportRawOrders',
         @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    DECLARE @cfg            VARCHAR(400),
            @priceTolTxt    VARCHAR(400),
            @priceTol       DECIMAL(9,4),
            @dedupeEnabled  BIT,
            @maxOrders      INT,
            @watermarkTxt   VARCHAR(400),
            @watermark      BIGINT = 0,
            @newWatermark   BIGINT = 0,
            @feedRows       INT = 0,
            @feedOrders     INT = 0,
            @rejectRows     INT = 0,
            @supersededRows INT = 0,
            @importedOrders INT = 0,
            @importedLines  INT = 0,
            @failedOrders   INT = 0,
            @retryCount     INT = 0,
            @msg            VARCHAR(2000),
            @rc             INT;

    /* set in the reconciliation pass at the bottom; declared here
       because the CATCH block reports it. */
    DECLARE @feedValue     DECIMAL(18,4) = 0,
            @importedValue DECIMAL(18,4) = 0;

    BEGIN TRY

        /* ========================================================
           SECTION 1 -- configuration
           ======================================================== */

        EXEC util.usp_GetConfig @ParamKey = 'import.price.variance.tolerance',
             @Default = '0.15', @Value = @priceTolTxt OUTPUT;
        SET @priceTol = ISNULL(TRY_CONVERT(DECIMAL(9,4), @priceTolTxt), 0.15);

        EXEC util.usp_GetConfig @ParamKey = 'import.dedupe.enabled',
             @Default = '1', @Value = @cfg OUTPUT;
        SET @dedupeEnabled = ISNULL(TRY_CONVERT(BIT, @cfg), 1);

        IF @MaxOrders IS NULL
        BEGIN
            EXEC util.usp_GetConfig @ParamKey = 'import.max.orders',
                 @Default = '5000', @Value = @cfg OUTPUT;
            SET @maxOrders = ISNULL(TRY_CONVERT(INT, @cfg), 5000);
        END
        ELSE
            SET @maxOrders = @MaxOrders;

        /* the watermark lives in util.ConfigParam because nobody
           wanted to add an etl.LoadWatermark table in 2018 and by
           the time anyone did it was load-bearing. It is the
           highest stg.RawOrder.RowId we have looked at, NOT the
           highest we imported -- rejects advance it too, otherwise
           every run re-validates every reject forever. */
        EXEC util.usp_GetConfig @ParamKey = 'watermark:import.raworder',
             @Default = '0', @Value = @watermarkTxt OUTPUT;
        SET @watermark = ISNULL(TRY_CONVERT(BIGINT, @watermarkTxt), 0);

        IF @DebugLevel > 0
            PRINT CONCAT('[import] watermark=', @watermark,
                         ' maxOrders=', @maxOrders,
                         ' priceTol=', @priceTol,
                         ' dedupe=', @dedupeEnabled,
                         ' source=', ISNULL(@SourceSystem, '(all)'),
                         ' dryRun=', @DryRun);

        /* ========================================================
           SECTION 2 -- preflight
           ======================================================== */

        IF @ReprocessRejects = 1
        BEGIN
            /* clear the stamps so the validation passes below get a
               clean look. Deliberately does NOT reset the
               watermark: a reject that has already been seen stays
               below the mark and will not be picked up again unless
               you reset it by hand. Yes, that means
               @ReprocessRejects on its own often does nothing.
               ETL-88. */
            UPDATE stg.RawOrder
               SET RejectReason = NULL
             WHERE IsProcessed = 0
               AND RejectReason IS NOT NULL
               AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem);

            IF @DebugLevel > 0 PRINT CONCAT('[import] cleared ', @@ROWCOUNT, ' reject stamps');
        END

        /* masters should already be loaded this batch. Warn if the
           staging tables still hold unprocessed rows, because that
           means usp_LoadCustomers / usp_LoadProducts either did not
           run or partially failed, and every order referencing a
           new customer or SKU is about to be rejected. */
        IF EXISTS (SELECT 1 FROM stg.RawCustomer WHERE IsProcessed = 0)
        BEGIN
            SELECT @msg = CONCAT(COUNT(*), ' unprocessed stg.RawCustomer row(s) -- '
                                 + 'etl.usp_LoadCustomers may not have run. '
                                 + 'Orders for new customers will reject.')
              FROM stg.RawCustomer WHERE IsProcessed = 0;
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0, @msg);
        END

        IF EXISTS (SELECT 1 FROM stg.RawProduct WHERE IsProcessed = 0)
        BEGIN
            SELECT @msg = CONCAT(COUNT(*), ' unprocessed stg.RawProduct row(s) -- '
                                 + 'etl.usp_LoadProducts may not have run. '
                                 + 'Orders for new SKUs will reject.')
              FROM stg.RawProduct WHERE IsProcessed = 0;
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0, @msg);
        END

        SELECT @feedRows   = COUNT(*),
               @feedOrders = COUNT(DISTINCT ExternalOrderRef)
          FROM stg.RawOrder
         WHERE IsProcessed = 0
           AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem);

        IF @feedRows = 0
        BEGIN
            EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = 0,
                 @Message = 'nothing to import';
            RETURN 0;
        END

        SELECT @feedValue = ISNULL(SUM(
                   ISNULL(TRY_CONVERT(INT, Qty), 0)
                 * ISNULL(TRY_CONVERT(DECIMAL(18,4), UnitPriceText), 0)), 0)
          FROM stg.RawOrder
         WHERE IsProcessed = 0
           AND (@SourceSystem IS NULL OR SourceSystem = @SourceSystem);

        IF @DebugLevel > 0
            PRINT CONCAT('[import] feed: ', @feedRows, ' rows, ',
                         @feedOrders, ' orders, value ', @feedValue);

        /* ========================================================
           SECTION 3 -- working tables
           ======================================================== */

        IF OBJECT_ID('tempdb..#reject')  IS NOT NULL DROP TABLE #reject;
        IF OBJECT_ID('tempdb..#scope')   IS NOT NULL DROP TABLE #scope;
        IF OBJECT_ID('tempdb..#orders')  IS NOT NULL DROP TABLE #orders;
        IF OBJECT_ID('tempdb..#imported') IS NOT NULL DROP TABLE #imported;

        CREATE TABLE #reject (
            RowId     BIGINT       NOT NULL,
            Severity  TINYINT      NOT NULL,   -- 1 structural, 2 referential, 3 business
            Reason    VARCHAR(300) NOT NULL,
            PRIMARY KEY (RowId, Severity, Reason)
        );

        /* the rows this run is allowed to touch. Materialised once
           so the three validation passes and the import all agree
           on scope even if the feed is still being written to. */
        CREATE TABLE #scope (
            RowId            BIGINT       NOT NULL PRIMARY KEY,
            ExternalOrderRef VARCHAR(60)  NULL,
            CustomerNo       VARCHAR(50)  NULL,
            Sku              VARCHAR(60)  NULL,
            QtyText          VARCHAR(20)  NULL,
            PriceText        VARCHAR(40)  NULL,
            PromoCode        VARCHAR(40)  NULL,
            CurrencyCode     CHAR(3)      NULL,
            OrderDateText    VARCHAR(40)  NULL,
            SourceSystem     VARCHAR(40)  NULL,
            Qty              INT          NULL,
            UnitPrice        DECIMAL(18,4) NULL,
            OrderDate        DATE         NULL,
            CustomerId       INT          NULL,
            ProductId        INT          NULL,
            IsSuperseded     BIT          NOT NULL DEFAULT 0
        );

        INSERT INTO #scope
            (RowId, ExternalOrderRef, CustomerNo, Sku, QtyText, PriceText,
             PromoCode, CurrencyCode, OrderDateText, SourceSystem,
             Qty, UnitPrice, OrderDate)
        SELECT r.RowId,
               LTRIM(RTRIM(r.ExternalOrderRef)),
               LTRIM(RTRIM(r.CustomerNo)),
               LTRIM(RTRIM(r.Sku)),
               r.Qty,
               r.UnitPriceText,
               NULLIF(LTRIM(RTRIM(r.PromoCode)), ''),
               r.CurrencyCode,
               r.OrderDateText,
               r.SourceSystem,
               TRY_CONVERT(INT, r.Qty),
               TRY_CONVERT(DECIMAL(18,4), r.UnitPriceText),
               TRY_CONVERT(DATE, r.OrderDateText)
          FROM stg.RawOrder r
         WHERE r.IsProcessed = 0
           AND (@SourceSystem IS NULL OR r.SourceSystem = @SourceSystem);

        /* resolve the keys once. LEFT JOIN so unresolved stays NULL
           and pass 2 can report it. Note the ACTIVE filters -- an
           INACTIVE customer or DISCONTINUED product resolves to
           NULL here and is reported as "unknown" rather than
           "inactive", which sends people looking for a data load
           problem that isn't there. */
        UPDATE s
           SET CustomerId = c.CustomerId
          FROM #scope s
          JOIN dbo.Customer c ON c.CustomerNo = s.CustomerNo AND c.Status = 'ACTIVE';

        UPDATE s
           SET ProductId = p.ProductId
          FROM #scope s
          JOIN dbo.Product p ON p.Sku = s.Sku AND p.Status = 'ACTIVE';

        /* ========================================================
           SECTION 4 -- validation pass 1: structural
           Can we parse the row at all.
           ======================================================== */

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT RowId, 1, 'missing ExternalOrderRef'
          FROM #scope WHERE ExternalOrderRef IS NULL OR ExternalOrderRef = '';

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT RowId, 1, 'missing customer no'
          FROM #scope WHERE CustomerNo IS NULL OR CustomerNo = '';

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT RowId, 1, 'missing sku'
          FROM #scope WHERE Sku IS NULL OR Sku = '';

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT RowId, 1, CONCAT('bad qty ''', ISNULL(QtyText, '(null)'), '''')
          FROM #scope WHERE Qty IS NULL OR Qty <= 0;

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT RowId, 1, CONCAT('bad price ''', ISNULL(PriceText, '(null)'), '''')
          FROM #scope WHERE UnitPrice IS NULL OR UnitPrice < 0;

        /* an unparseable date is not fatal -- we do not actually use
           it, sales.usp_CreateOrder stamps SYSUTCDATETIME(). Logged
           at severity 3 so it does not kill the order. This is why
           imported orders all carry the import date rather than the
           real order date, which finance has raised twice. */
        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT RowId, 3, CONCAT('unparseable order date ''', ISNULL(OrderDateText, '(null)'), ''' (ignored)')
          FROM #scope WHERE OrderDateText IS NOT NULL AND OrderDate IS NULL;

        IF @DebugLevel > 0
            PRINT CONCAT('[import] pass 1 rejects: ',
                         (SELECT COUNT(*) FROM #reject WHERE Severity = 1));

        /* ========================================================
           SECTION 5 -- validation pass 2: referential
           ======================================================== */

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 2, CONCAT('unknown customer ', ISNULL(s.CustomerNo, '(null)'))
          FROM #scope s
         WHERE s.CustomerId IS NULL
           AND s.CustomerNo IS NOT NULL AND s.CustomerNo <> '';

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 2, CONCAT('unknown sku ', ISNULL(s.Sku, '(null)'))
          FROM #scope s
         WHERE s.ProductId IS NULL
           AND s.Sku IS NOT NULL AND s.Sku <> '';

        /* distinguish "not there at all" from "there but not ACTIVE",
           because the fix is different. Costs two more scans and is
           worth it -- this was the single biggest source of
           "the ETL is broken" tickets before it went in. */
        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 2, CONCAT('customer ', s.CustomerNo, ' exists but status is ',
                                  (SELECT TOP (1) c2.Status FROM dbo.Customer c2
                                    WHERE c2.CustomerNo = s.CustomerNo ORDER BY c2.CustomerId))
          FROM #scope s
         WHERE s.CustomerId IS NULL
           AND EXISTS (SELECT 1 FROM dbo.Customer c3 WHERE c3.CustomerNo = s.CustomerNo);

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 2, CONCAT('sku ', s.Sku, ' exists but is DISCONTINUED')
          FROM #scope s
         WHERE s.ProductId IS NULL
           AND EXISTS (SELECT 1 FROM dbo.Product p2
                        WHERE p2.Sku = s.Sku AND p2.Status = 'DISCONTINUED');

        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 2, CONCAT('unknown currency ', ISNULL(s.CurrencyCode, '(null)'))
          FROM #scope s
         WHERE s.CurrencyCode IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM ref.Currency rc WHERE rc.CurrencyCode = s.CurrencyCode);

        IF @DebugLevel > 0
            PRINT CONCAT('[import] pass 2 rejects: ',
                         (SELECT COUNT(*) FROM #reject WHERE Severity = 2));

        /* ========================================================
           SECTION 6 -- validation pass 3: business rules
           These are the ones that need the resolved keys, so they
           have to come after pass 2.
           ======================================================== */

        /* already imported. The external ref is the source system's
           order id and we treat it as unique forever. There is no
           unique index enforcing that on sales.OrderHeader (the
           external ref is not even stored there -- it goes nowhere,
           which is ETL-40 and the reason this check has to go
           looking at the staging table's own history instead). */
        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 3, CONCAT('ExternalOrderRef ', s.ExternalOrderRef, ' already imported')
          FROM #scope s
         WHERE EXISTS (
                   SELECT 1 FROM stg.RawOrder prior
                    WHERE prior.ExternalOrderRef = s.ExternalOrderRef
                      AND prior.IsProcessed = 1);

        /* blocked customers. usp_CreateOrder only checks ACTIVE, and
           BLOCKED is not ACTIVE, so this would be caught anyway --
           but it would be caught as a THROW inside the cursor,
           which costs a rollback and an ErrorLog row per order.
           Cheaper to reject up front. */
        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 3, CONCAT('customer ', s.CustomerNo, ' is BLOCKED')
          FROM #scope s
          JOIN dbo.Customer c ON c.CustomerId = s.CustomerId
         WHERE c.Status = 'BLOCKED';

        /* price variance against the list price. The feed price wins
           (see the header), so this was supposed to be the thing
           standing between a fat-fingered source system and a real
           order at the wrong price.

           It isn't, for two separate reasons, and ETL-91 covers both:

           1. It is filed at severity 3. Section 10 only blocks an
              order on severity 1 or 2, so this has never rejected
              anything in its life -- it stamps a RejectReason on a
              row that then imports anyway. Every audit that has
              looked for "the price check" has found this INSERT,
              read the word 'reject', and moved on. If you promote it
              to severity 2, read point 2 first.

           2. It compares the feed price against dbo.Product.ListPrice
              which is held in USD, WITHOUT converting the feed price
              to USD -- so a non-USD order is measured against the
              wrong benchmark and either always passes or always
              fails depending on the pair. At the default tolerance
              of 0.15 a GBP feed (~0.79) is 21% out and a CAD feed
              (~1.36) is 36% out, so promoting this to blocking
              rejects essentially every GBP and CAD order in the
              feed while letting the genuinely wrong USD prices
              through at 3%.

           So: fixing the severity without fixing the currency makes
           it dramatically worse. Fix the comparison first. */
        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 3,
               CONCAT('price ', s.UnitPrice, ' varies from list ', p.ListPrice,
                      ' by more than ', CAST(@priceTol * 100 AS INT), '%')
          FROM #scope s
          JOIN dbo.Product p ON p.ProductId = s.ProductId
         WHERE p.ListPrice IS NOT NULL
           AND p.ListPrice > 0
           AND s.UnitPrice IS NOT NULL
           AND ABS(s.UnitPrice - p.ListPrice) / p.ListPrice > @priceTol;

        /* unknown promo code. Not a rejection -- the promo is applied
           inside its own TRY/CATCH during import and a bad code just
           doesn't get applied. Recorded at severity 3 as a warning
           so it shows up in the reject report without blocking. */
        INSERT INTO #reject (RowId, Severity, Reason)
        SELECT s.RowId, 3, CONCAT('unknown promo code ', s.PromoCode, ' (will be skipped)')
          FROM #scope s
         WHERE s.PromoCode IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sales.Promotion pr WHERE pr.PromoCode = s.PromoCode);

        IF @DebugLevel > 0
            PRINT CONCAT('[import] pass 3 rejects: ',
                         (SELECT COUNT(*) FROM #reject WHERE Severity = 3));

        /* ========================================================
           SECTION 7 -- dedupe within the feed
           The same ExternalOrderRef can arrive more than once in one
           file when the source system retries. Keep the highest
           RowId per (ref, sku) and mark the rest superseded.

           Note this dedupes at (ref, sku) grain, not (ref) grain: a
           retry that changed the line-up of an order leaves the old
           lines behind as real lines, because they are not
           duplicates of anything in the new set. That is a known
           hole and the reason the reconciliation pass at the bottom
           exists.
           ======================================================== */

        IF @dedupeEnabled = 1
        BEGIN
            UPDATE s
               SET IsSuperseded = 1
              FROM #scope s
             WHERE EXISTS (
                       SELECT 1 FROM #scope newer
                        WHERE newer.ExternalOrderRef = s.ExternalOrderRef
                          AND newer.Sku              = s.Sku
                          AND newer.RowId            > s.RowId);

            SET @supersededRows = @@ROWCOUNT;

            IF @supersededRows > 0
            BEGIN
                INSERT INTO #reject (RowId, Severity, Reason)
                SELECT RowId, 3, 'superseded by a later row for the same ref+sku in this feed'
                  FROM #scope WHERE IsSuperseded = 1;

                INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0,
                        CONCAT(@supersededRows, ' row(s) superseded by later duplicates in the same feed'));
            END

            IF @DebugLevel > 0 PRINT CONCAT('[import] superseded ', @supersededRows, ' rows');
        END

        /* ========================================================
           SECTION 8 -- follow merged-customer chains
           dbo.usp_MergeCustomers points the loser at the survivor
           via MergedIntoId and sets Status = 'MERGED'. A feed that
           still knows the old CustomerNo resolves to nothing in
           section 3 (the ACTIVE filter), so chase the chain here
           and rewrite CustomerId to the survivor.

           Chains happen: A -> B, then B -> C. Depth is bounded at
           10 because dbo.proc_FixCustomerDupes managed to create a
           two-node cycle in 2020 (A -> B -> A) and this loop ran
           until the connection was killed.
           ======================================================== */

        DECLARE @chainRow BIGINT, @chainNo VARCHAR(50), @chainId INT,
                @chainDepth TINYINT, @chainTarget INT, @chainResolved INT = 0;

        DECLARE merge_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT s.RowId, s.CustomerNo
              FROM #scope s
             WHERE s.CustomerId IS NULL
               AND s.CustomerNo IS NOT NULL
               AND EXISTS (SELECT 1 FROM dbo.Customer c
                            WHERE c.CustomerNo = s.CustomerNo AND c.Status = 'MERGED');
        OPEN merge_cur;
        FETCH NEXT FROM merge_cur INTO @chainRow, @chainNo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @chainDepth  = 0;
            SET @chainTarget = NULL;

            SELECT TOP (1) @chainId = CustomerId, @chainTarget = MergedIntoId
              FROM dbo.Customer
             WHERE CustomerNo = @chainNo
             ORDER BY CustomerId;

            WHILE @chainTarget IS NOT NULL AND @chainDepth < 10
            BEGIN
                SET @chainId = @chainTarget;
                SET @chainTarget = NULL;

                SELECT @chainTarget = MergedIntoId
                  FROM dbo.Customer
                 WHERE CustomerId = @chainId
                   AND Status = 'MERGED';

                SET @chainDepth = @chainDepth + 1;
            END

            IF @chainDepth >= 10
            BEGIN
                INSERT INTO #reject (RowId, Severity, Reason)
                VALUES (@chainRow, 2,
                        CONCAT('merged-customer chain for ', @chainNo,
                               ' exceeded depth 10 -- possible cycle'));

                INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0,
                        CONCAT('merge chain for customer ', @chainNo,
                               ' looks circular -- check dbo.Customer.MergedIntoId'));
            END
            ELSE IF EXISTS (SELECT 1 FROM dbo.Customer
                             WHERE CustomerId = @chainId AND Status = 'ACTIVE')
            BEGIN
                UPDATE #scope SET CustomerId = @chainId WHERE RowId = @chainRow;

                /* the row was rejected as "unknown customer" in
                   pass 2. Un-reject it. Deleting from #reject like
                   this is why the passes cannot be reordered. */
                DELETE FROM #reject
                 WHERE RowId = @chainRow
                   AND Severity = 2
                   AND Reason LIKE 'unknown customer%';

                DELETE FROM #reject
                 WHERE RowId = @chainRow
                   AND Severity = 2
                   AND Reason LIKE '%exists but status is MERGED%';

                SET @chainResolved = @chainResolved + 1;
            END

            FETCH NEXT FROM merge_cur INTO @chainRow, @chainNo;
        END
        CLOSE merge_cur; DEALLOCATE merge_cur;

        IF @chainResolved > 0 AND @DebugLevel > 0
            PRINT CONCAT('[import] resolved ', @chainResolved, ' rows through merged customers');

        /* ========================================================
           SECTION 9 -- stamp the rejects back onto staging
           Highest severity wins for the stamp; the rest are only
           visible in the log. Severity 3 alone does NOT block the
           order -- those are warnings.
           ======================================================== */

        UPDATE r
           SET RejectReason = x.Reason
          FROM stg.RawOrder r
          JOIN (
                SELECT rj.RowId,
                       CONCAT('[S', MIN(rj.Severity), '] ',
                              MIN(rj.Reason)) AS Reason
                  FROM #reject rj
                 GROUP BY rj.RowId
               ) x ON x.RowId = r.RowId
         WHERE r.IsProcessed = 0;

        SELECT @rejectRows = COUNT(DISTINCT RowId) FROM #reject WHERE Severity <= 2;

        /* ========================================================
           SECTION 10 -- assemble the importable order set
           An order is importable when none of its non-superseded
           rows carry a blocking reject (severity 1 or 2).
           ======================================================== */

        CREATE TABLE #orders (
            ExternalOrderRef VARCHAR(60)  NOT NULL PRIMARY KEY,
            CustomerId       INT          NOT NULL,
            CurrencyCode     CHAR(3)      NULL,
            PromoCode        VARCHAR(40)  NULL,
            LineCount        INT          NOT NULL,
            FeedValue        DECIMAL(18,4) NOT NULL,
            Attempts         TINYINT      NOT NULL DEFAULT 0,
            Status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
            OrderId          INT          NULL,
            OrderNo          VARCHAR(20)  NULL,
            FailReason       VARCHAR(400) NULL
        );

        INSERT INTO #orders
            (ExternalOrderRef, CustomerId, CurrencyCode, PromoCode, LineCount, FeedValue)
        SELECT TOP (@maxOrders)
               s.ExternalOrderRef,
               MAX(s.CustomerId),
               MAX(s.CurrencyCode),
               MAX(s.PromoCode),
               COUNT(*),
               SUM(s.Qty * s.UnitPrice)
          FROM #scope s
         WHERE s.IsSuperseded = 0
           AND s.ExternalOrderRef IS NOT NULL
           AND s.CustomerId IS NOT NULL
         GROUP BY s.ExternalOrderRef
        HAVING NOT EXISTS (
                   SELECT 1
                     FROM #scope s2
                     JOIN #reject rj ON rj.RowId = s2.RowId
                    WHERE s2.ExternalOrderRef = s.ExternalOrderRef
                      AND s2.IsSuperseded = 0
                      AND rj.Severity <= 2)
           /* MAX(CustomerNo) across the order's lines assumes every
              line agrees on the customer. They do not always. The
              order gets whichever customer sorts highest, which is
              arbitrary. ETL-63. */
           AND COUNT(DISTINCT s.CustomerId) = 1
         ORDER BY s.ExternalOrderRef;

        IF @DebugLevel > 0
            PRINT CONCAT('[import] importable orders: ', (SELECT COUNT(*) FROM #orders));

        /* orders dropped for disagreeing with themselves about the
           customer -- worth calling out separately, it usually
           means two source systems collided on a ref. */
        IF EXISTS (SELECT 1 FROM #scope s
                    WHERE s.IsSuperseded = 0 AND s.CustomerId IS NOT NULL
                    GROUP BY s.ExternalOrderRef
                   HAVING COUNT(DISTINCT s.CustomerId) > 1)
        BEGIN
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            SELECT @BatchId, 'etl.usp_ImportRawOrders', 0,
                   CONCAT('ExternalOrderRef ', s.ExternalOrderRef,
                          ' has lines for ', COUNT(DISTINCT s.CustomerId),
                          ' different customers -- not imported')
              FROM #scope s
             WHERE s.IsSuperseded = 0 AND s.CustomerId IS NOT NULL
             GROUP BY s.ExternalOrderRef
            HAVING COUNT(DISTINCT s.CustomerId) > 1;
        END

        IF @DryRun = 1
        BEGIN
            SELECT @msg = CONCAT('DRYRUN: would import ', COUNT(*), ' orders (',
                                 SUM(LineCount), ' lines, value ', SUM(FeedValue), '); ',
                                 @rejectRows, ' rows rejected, ',
                                 @supersededRows, ' superseded')
              FROM #orders;

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0, @msg);

            EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = 0, @Message = @msg;
            RETURN 0;
        END

        CREATE TABLE #imported (
            ExternalOrderRef VARCHAR(60) NOT NULL,
            OrderId          INT         NOT NULL,
            LineNo           INT         NOT NULL,
            ProductId        INT         NOT NULL,
            Qty              INT         NOT NULL,
            UnitPrice        DECIMAL(18,4) NOT NULL
        );

        /* ========================================================
           SECTION 11 -- the import
           Outer cursor over orders, inner cursor over that order's
           lines, wrapped in a retry loop for deadlock victims.

           One transaction per order. Not one per batch: a single
           bad order should not take the night's work with it, and
           a batch-wide transaction against sales.OrderLine held for
           the length of this proc blocks the web tier.
           ======================================================== */

        DECLARE @extRef VARCHAR(60), @custId INT, @ccy CHAR(3), @promo VARCHAR(40),
                @orderId INT, @orderNo VARCHAR(20), @lineCount INT;
        DECLARE @sku VARCHAR(60), @qty INT, @price DECIMAL(18,4), @pid INT, @lineSeq INT;
        DECLARE @maxAttempts TINYINT, @attempt TINYINT, @retryDelay CHAR(8) = '00:00:02';
        DECLARE @errNum INT, @errMsg VARCHAR(2000);

        EXEC util.usp_GetConfig @ParamKey = 'batch.step.retry.max',
             @Default = '2', @Value = @cfg OUTPUT;
        SET @maxAttempts = ISNULL(TRY_CONVERT(TINYINT, @cfg), 2) + 1;

        DECLARE ord_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT ExternalOrderRef, CustomerId, CurrencyCode, PromoCode, LineCount
              FROM #orders
             ORDER BY ExternalOrderRef;
        OPEN ord_cur;
        FETCH NEXT FROM ord_cur INTO @extRef, @custId, @ccy, @promo, @lineCount;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @attempt = 0;

            WHILE @attempt < @maxAttempts
            BEGIN
                SET @attempt  = @attempt + 1;
                SET @orderId  = NULL;
                SET @orderNo  = NULL;
                SET @errNum   = NULL;
                SET @lineSeq  = 0;

                BEGIN TRY
                    BEGIN TRAN;

                    EXEC sales.usp_CreateOrder
                         @CustomerId   = @custId,
                         @CurrencyCode = @ccy,
                         @OrderId      = @orderId OUTPUT,
                         @OrderNo      = @orderNo OUTPUT;

                    /* ---- lines ---- */
                    DECLARE ln_cur CURSOR LOCAL FAST_FORWARD FOR
                        SELECT s.ProductId, s.Qty, s.UnitPrice, s.Sku
                          FROM #scope s
                         WHERE s.ExternalOrderRef = @extRef
                           AND s.IsSuperseded = 0
                           AND s.ProductId IS NOT NULL
                         ORDER BY s.RowId;      -- feed order. AddOrderLine
                                                -- merges repeats, so this
                                                -- decides whose price sticks.
                    OPEN ln_cur;
                    FETCH NEXT FROM ln_cur INTO @pid, @qty, @price, @sku;
                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        EXEC sales.usp_AddOrderLine
                             @OrderId       = @orderId,
                             @ProductId     = @pid,
                             @Qty           = @qty,
                             @OverridePrice = @price;

                        SET @lineSeq = @lineSeq + 1;

                        INSERT INTO #imported
                            (ExternalOrderRef, OrderId, LineNo, ProductId, Qty, UnitPrice)
                        VALUES (@extRef, @orderId, @lineSeq, @pid, @qty, @price);

                        FETCH NEXT FROM ln_cur INTO @pid, @qty, @price, @sku;
                    END
                    CLOSE ln_cur; DEALLOCATE ln_cur;

                    /* ---- promotion ---- */
                    IF @promo IS NOT NULL AND LTRIM(RTRIM(@promo)) <> ''
                    BEGIN
                        BEGIN TRY
                            EXEC sales.usp_ApplyPromotion @OrderId = @orderId, @PromoCode = @promo;
                        END TRY
                        BEGIN CATCH
                            /* an invalid promo on import must not kill
                               the order -- the customer was already
                               charged whatever the source system said.
                               Log and carry on with the order at full
                               price, which means the imported total can
                               exceed what the customer actually paid.
                               That difference shows up in
                               fin.usp_ReconcileSettlements as a
                               variance and is written off monthly. */
                            EXEC util.usp_LogError
                                 @ProcName = 'etl.usp_ImportRawOrders(promo)',
                                 @BatchId  = @BatchId;
                        END CATCH
                    END

                    /* ---- confirm ---- */
                    IF @AutoConfirm = 1
                        EXEC sales.usp_ConfirmOrder @OrderId = @orderId, @AllowBackorder = 1;

                    /* ---- mark the feed rows done ---- */
                    UPDATE stg.RawOrder
                       SET IsProcessed = 1
                     WHERE RowId IN (SELECT RowId FROM #scope
                                      WHERE ExternalOrderRef = @extRef
                                        AND IsSuperseded = 0);

                    /* superseded rows are also done -- they are never
                       coming back. Stamped, not silently dropped. */
                    UPDATE stg.RawOrder
                       SET IsProcessed = 1
                     WHERE RowId IN (SELECT RowId FROM #scope
                                      WHERE ExternalOrderRef = @extRef
                                        AND IsSuperseded = 1);

                    COMMIT;

                    UPDATE #orders
                       SET Status = 'IMPORTED', OrderId = @orderId,
                           OrderNo = @orderNo, Attempts = @attempt
                     WHERE ExternalOrderRef = @extRef;

                    SET @importedOrders = @importedOrders + 1;
                    SET @importedLines  = @importedLines + @lineSeq;

                    BREAK;   -- out of the retry loop, on to the next order
                END TRY
                BEGIN CATCH
                    SET @errNum = ERROR_NUMBER();
                    SET @errMsg = ERROR_MESSAGE();

                    IF CURSOR_STATUS('local','ln_cur') >= 0
                        BEGIN CLOSE ln_cur; DEALLOCATE ln_cur; END

                    /* XACT_STATE() = -1 means the transaction is
                       doomed and the only legal move is a full
                       rollback. Checking it matters: a plain
                       ROLLBACK on an already-rolled-back
                       transaction throws a second error that hides
                       the first. */
                    IF XACT_STATE() <> 0 ROLLBACK;

                    EXEC util.usp_LogError
                         @ProcName = 'etl.usp_ImportRawOrders',
                         @BatchId  = @BatchId;

                    /* 1205 deadlock victim, 1222 lock timeout --
                       both worth another go. Anything else is
                       deterministic and retrying just burns time. */
                    IF @errNum IN (1205, 1222) AND @attempt < @maxAttempts
                    BEGIN
                        SET @retryCount = @retryCount + 1;

                        IF @DebugLevel > 0
                            PRINT CONCAT('[import] ', @extRef, ' hit ', @errNum,
                                         ', retry ', @attempt, ' of ', @maxAttempts);

                        WAITFOR DELAY @retryDelay;
                        CONTINUE;
                    END

                    /* give up on this order */
                    UPDATE #orders
                       SET Status = 'FAILED', Attempts = @attempt,
                           FailReason = LEFT(CONCAT('err ', @errNum, ': ', @errMsg), 400)
                     WHERE ExternalOrderRef = @extRef;

                    UPDATE stg.RawOrder
                       SET RejectReason = LEFT(CONCAT('[S1] import failed err ', @errNum,
                                                      ' - see util.ErrorLog'), 400)
                     WHERE RowId IN (SELECT RowId FROM #scope
                                      WHERE ExternalOrderRef = @extRef)
                       AND IsProcessed = 0;

                    SET @failedOrders = @failedOrders + 1;

                    IF @ContinueOnError = 0
                    BEGIN
                        CLOSE ord_cur; DEALLOCATE ord_cur;
                        THROW;
                    END

                    BREAK;
                END CATCH
            END  /* retry loop */

            FETCH NEXT FROM ord_cur INTO @extRef, @custId, @ccy, @promo, @lineCount;
        END
        CLOSE ord_cur; DEALLOCATE ord_cur;

        /* ========================================================
           SECTION 12 -- reconciliation
           Did we import what arrived. Compares the feed's own line
           count and extended value against what we actually wrote,
           per order. Discrepancies here are expected in two cases
           (AddOrderLine merging repeated SKUs, and promotions
           changing the total) so this warns rather than fails.
           ======================================================== */

        SELECT @importedValue = ISNULL(SUM(Qty * UnitPrice), 0) FROM #imported;

        IF ABS(@importedValue - @feedValue) > 0.01
        BEGIN
            /* not necessarily wrong -- rejected and superseded rows
               are in @feedValue but not @importedValue. Break it
               down so the number is actionable rather than alarming. */
            SET @msg = CONCAT('import value reconciliation: feed ', @feedValue,
                              ' vs imported ', @importedValue,
                              ' (delta ', @importedValue - @feedValue, '). ',
                              'rejected rows ', @rejectRows,
                              ', superseded ', @supersededRows,
                              ', failed orders ', @failedOrders, '.');

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0, @msg);
        END

        /* per-order line count check. This one is a real signal:
           if an order imported fewer lines than the feed had, and
           the difference is not explained by a repeated SKU, we
           lost a line. */
        IF EXISTS (
            SELECT 1
              FROM #orders o
              LEFT JOIN (SELECT ExternalOrderRef, COUNT(*) AS Lines
                           FROM #imported GROUP BY ExternalOrderRef) i
                     ON i.ExternalOrderRef = o.ExternalOrderRef
             WHERE o.Status = 'IMPORTED'
               AND ISNULL(i.Lines, 0) <> o.LineCount)
        BEGIN
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            SELECT @BatchId, 'etl.usp_ImportRawOrders', 0,
                   CONCAT('order ', o.ExternalOrderRef, ' -> ', o.OrderNo,
                          ': feed had ', o.LineCount, ' lines, imported ',
                          ISNULL(i.Lines, 0),
                          CASE WHEN ISNULL(i.Lines, 0) < o.LineCount
                               THEN ' (repeated SKU merged, or a line was lost)'
                               ELSE '' END)
              FROM #orders o
              LEFT JOIN (SELECT ExternalOrderRef, COUNT(*) AS Lines
                           FROM #imported GROUP BY ExternalOrderRef) i
                     ON i.ExternalOrderRef = o.ExternalOrderRef
             WHERE o.Status = 'IMPORTED'
               AND ISNULL(i.Lines, 0) <> o.LineCount;
        END

        /* ========================================================
           SECTION 13 -- advance the watermark
           Highest RowId we looked at, imported or not. Only moved
           when nothing failed: leaving it where it is means a
           re-run picks the failures back up.
           ======================================================== */

        SELECT @newWatermark = ISNULL(MAX(RowId), @watermark) FROM #scope;

        IF @failedOrders = 0
        BEGIN
            UPDATE util.ConfigParam
               SET ParamValue  = CAST(@newWatermark AS VARCHAR(400)),
                   ModifiedUtc = SYSUTCDATETIME()
             WHERE ParamKey = 'watermark:import.raworder';

            IF @@ROWCOUNT = 0
                INSERT INTO util.ConfigParam (ParamKey, ParamValue, ParamType, Description)
                VALUES ('watermark:import.raworder', CAST(@newWatermark AS VARCHAR(400)),
                        'int', 'highest stg.RawOrder.RowId processed by etl.usp_ImportRawOrders');
        END
        ELSE
        BEGIN
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'etl.usp_ImportRawOrders', 0,
                    CONCAT(@failedOrders, ' order(s) failed -- watermark left at ',
                           @watermark, ' rather than advancing to ', @newWatermark));
        END

        /* ========================================================
           SECTION 14 -- done
           ======================================================== */

        SET @msg = CONCAT('imported ', @importedOrders, '/', @feedOrders, ' orders, ',
                          @importedLines, ' lines; ',
                          @rejectRows, ' rows rejected, ',
                          @supersededRows, ' superseded, ',
                          @failedOrders, ' failed',
                          CASE WHEN @retryCount > 0
                               THEN CONCAT(', ', @retryCount, ' retries') ELSE '' END);

        EXEC util.usp_LogEnd @ProcLogId = @plog,
             @RowsAffected = @importedOrders, @Message = @msg;

        IF OBJECT_ID('tempdb..#reject')   IS NOT NULL DROP TABLE #reject;
        IF OBJECT_ID('tempdb..#scope')    IS NOT NULL DROP TABLE #scope;
        IF OBJECT_ID('tempdb..#orders')   IS NOT NULL DROP TABLE #orders;
        IF OBJECT_ID('tempdb..#imported') IS NOT NULL DROP TABLE #imported;

        RETURN 0;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ln_cur')    >= 0 BEGIN CLOSE ln_cur;    DEALLOCATE ln_cur;    END
        IF CURSOR_STATUS('local','ord_cur')   >= 0 BEGIN CLOSE ord_cur;   DEALLOCATE ord_cur;   END
        IF CURSOR_STATUS('local','merge_cur') >= 0 BEGIN CLOSE merge_cur; DEALLOCATE merge_cur; END

        IF XACT_STATE() <> 0 ROLLBACK;

        EXEC util.usp_LogError @ProcName = 'etl.usp_ImportRawOrders', @BatchId = @BatchId;
        EXEC util.usp_LogEnd   @ProcLogId = @plog, @Status = 'FAILED',
             @Message = CONCAT('failed after ', @importedOrders, ' orders');
        THROW;
    END CATCH
END
GO
