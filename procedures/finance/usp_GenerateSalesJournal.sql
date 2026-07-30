/* ============================================================
   fin.usp_GenerateSalesJournal

   Builds and posts the daily sales journal. This started life in
   2017 as a forty-line proc that summed a day's orders and posted
   one balanced entry. It is not that any more. Read this header
   before changing anything below it.

   ------------------------------------------------------------
   WHAT IT POSTS
   ------------------------------------------------------------
   Base entry (all modes):
     DR  1200 Accounts Receivable      grand total of in-scope orders
       CR 4000 Sales Revenue           net of tax and discount
       CR 2200 Sales Tax Payable       tax collected
     DR  5000 COGS                     cost of goods shipped
       CR 1300 Inventory               cost of goods shipped

   Intercompany pass (@IncludeIntercompany = 1):
     Orders shipped out of a warehouse whose country differs from
     the customer's country are treated as a sale from the shipping
     entity to the selling entity, then on to the customer. The
     revenue on those orders moves to 4100 and the receivable to
     1210, with a markup (config journal.ic.markup.pct) recognised
     against the shipping entity.
     DR  1210 AR Intercompany
       CR 4100 Intercompany Revenue
     The markup is NOT eliminated here. Group elimination happens
     in the consolidation system, not in RetailDW. Do not "fix"
     the fact that group revenue is overstated by the markup --
     that is someone else's journal.

   Deferral pass (@DeferUnshipped = 1):
     Orders that reached PAID but have no shipment yet are not
     revenue. Their net moves out of 4000 and into 2400.
     DR  4000 Sales Revenue
       CR 2400 Deferred Revenue
     They come back out of 2400 on the day they ship, which is
     handled by... nothing. See FIN-503. In practice the deferral
     is recomputed from scratch each night as a delta against the
     prior night's balance, which is why the proc reads yesterday's
     journal near the bottom.

   FX revaluation pass (@FxRevaluation = 1):
     Month-end only. Revalues the open AR balance per currency at
     the period-end rate against the rate it was booked at.
     DR/CR 1200 vs 6900 FX Gain/Loss

   Rounding:
     Everything is converted to USD per order, per amount, which
     means the sum of rounded parts rarely equals the rounded sum.
     The residual is plugged into 9999 FX Rounding Suspense. If the
     plug exceeds config journal.rounding.tolerance we throw rather
     than post a silently wrong entry (FIN-260).

   ------------------------------------------------------------
   MODES
   ------------------------------------------------------------
   @Mode = 'ACCRUAL'  in-scope = orders whose ModifiedUtc falls on
                      the business date and whose status is
                      PAID/SHIPPED/COMPLETED.
   @Mode = 'CASH'     in-scope = orders with a payment CAPTURED or
                      REFUNDED on the business date, regardless of
                      order status.
   @Mode = 'BOTH'     runs ACCRUAL, then posts a second entry for
                      the timing difference between the two bases.

   ModifiedUtc, not OrderDate. This is deliberate and it is also a
   problem: any UPDATE to OrderHeader touches ModifiedUtc, so an
   order whose address was corrected three weeks after the sale is
   picked up again by that night's journal. The 2019 fix was to
   compare against the prior posting and only book the delta; the
   2020 rewrite dropped that and nobody noticed for a quarter. See
   FIN-412. Reconciliation catches the worst of it.

   'BOTH' double-counts orders that were both modified and captured
   on the same business date. Known. FIN-412 again. Finance runs
   ACCRUAL in practice and CASH only at year end, so it has never
   been worth fixing.

   ------------------------------------------------------------
   RE-RUNS
   ------------------------------------------------------------
   Posting twice for the same date is blocked unless @ReRun = 1, in
   which case the previous SALES entry for the date is flipped to
   REVERSED first (a contra entry is NOT posted -- fin.usp_ReverseJournal
   does that, and calling it from here caused a nested-transaction
   mess in 2021, so it is done by hand).

   @WhatIf = 1 computes everything and logs the intended spec
   without posting. Safe on prod. @DebugLevel > 0 PRINTs the
   intermediate sets; do not leave it on in the SQL Agent job, it
   floods the job history.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE fin.usp_GenerateSalesJournal
    @BusinessDate        DATE,
    @BatchId             UNIQUEIDENTIFIER = NULL,
    @Mode                VARCHAR(10)      = NULL,   -- NULL -> config journal.mode
    @IncludeIntercompany BIT              = NULL,   -- NULL -> config
    @FxRevaluation       BIT              = NULL,   -- NULL -> config
    @DeferUnshipped      BIT              = NULL,   -- NULL -> config
    @ReRun               BIT              = 0,
    @WhatIf              BIT              = 0,
    @DebugLevel          TINYINT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'fin.usp_GenerateSalesJournal',
         @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    /* ------------------------------------------------------------
       everything gets declared up front. Not because it's tidy --
       because a couple of these are referenced inside CATCH blocks
       and cursors that would otherwise not see them.
       ------------------------------------------------------------ */
    DECLARE @cfg              VARCHAR(400),
            @modeCfg          VARCHAR(400),
            @tolTxt           VARCHAR(400),
            @icPctTxt         VARCHAR(400),
            @tol              DECIMAL(18,4),
            @icPct            DECIMAL(9,6),
            @fiscalYear       SMALLINT,
            @fiscalPeriod     TINYINT,
            @isPeriodEnd      BIT = 0,
            @priorJournalId   INT,
            @priorDeferBal    DECIMAL(18,4) = 0,
            @jid              INT,
            @jidTiming        INT,
            @spec             VARCHAR(MAX),
            @timingSpec       VARCHAR(MAX),
            @totalNet         DECIMAL(18,4) = 0,
            @totalTax         DECIMAL(18,4) = 0,
            @totalGrand       DECIMAL(18,4) = 0,
            @totalShip        DECIMAL(18,4) = 0,
            @cogs             DECIMAL(18,4) = 0,
            @cogsReturned     DECIMAL(18,4) = 0,
            @icNet            DECIMAL(18,4) = 0,
            @icGrand          DECIMAL(18,4) = 0,
            @icMarkup         DECIMAL(18,4) = 0,
            @deferNet         DECIMAL(18,4) = 0,
            @deferDelta       DECIMAL(18,4) = 0,
            @revalGain        DECIMAL(18,4) = 0,
            @revalLoss        DECIMAL(18,4) = 0,
            @plug             DECIMAL(18,4) = 0,
            @drTotal          DECIMAL(18,4) = 0,
            @crTotal          DECIMAL(18,4) = 0,
            @orderCount       INT = 0,
            @noRateCount      INT = 0,
            @rc               INT,
            @msg              VARCHAR(2000),
            @attempt          TINYINT = 0;

    /* used only by the reconciliation cross-check at the very
       bottom. Declared here because it used to be set in the
       revenue cursor and something still might. */
    DECLARE @rptNetRevenue DECIMAL(18,4) = NULL;

    BEGIN TRY

        /* ========================================================
           SECTION 1 -- configuration
           Every switch has a config key AND a hardcoded default in
           this proc, and they do not all agree. The code default is
           what runs when ConfigParam is missing a row, which on a
           freshly restored dev box is always. Grep 'ConfigParam'
           before trusting any of these.
           ======================================================== */

        IF @Mode IS NULL
        BEGIN
            EXEC util.usp_GetConfig @ParamKey = 'journal.mode',
                 @Default = 'ACCRUAL', @Value = @modeCfg OUTPUT;
            SET @Mode = UPPER(LTRIM(RTRIM(ISNULL(@modeCfg, 'ACCRUAL'))));
        END
        ELSE
            SET @Mode = UPPER(LTRIM(RTRIM(@Mode)));

        IF @Mode NOT IN ('ACCRUAL','CASH','BOTH')
            THROW 55010, 'Unknown @Mode -- expected ACCRUAL, CASH or BOTH', 1;

        IF @IncludeIntercompany IS NULL
        BEGIN
            EXEC util.usp_GetConfig @ParamKey = 'journal.intercompany.enabled',
                 @Default = '1', @Value = @cfg OUTPUT;
            SET @IncludeIntercompany = ISNULL(TRY_CONVERT(BIT, @cfg), 1);
        END

        IF @FxRevaluation IS NULL
        BEGIN
            EXEC util.usp_GetConfig @ParamKey = 'journal.fx.reval.enabled',
                 @Default = '0', @Value = @cfg OUTPUT;
            SET @FxRevaluation = ISNULL(TRY_CONVERT(BIT, @cfg), 0);
        END

        IF @DeferUnshipped IS NULL
        BEGIN
            EXEC util.usp_GetConfig @ParamKey = 'journal.defer.unshipped',
                 @Default = '1', @Value = @cfg OUTPUT;
            SET @DeferUnshipped = ISNULL(TRY_CONVERT(BIT, @cfg), 1);
        END

        EXEC util.usp_GetConfig @ParamKey = 'journal.rounding.tolerance',
             @Default = '0.05', @Value = @tolTxt OUTPUT;
        SET @tol = ISNULL(TRY_CONVERT(DECIMAL(18,4), @tolTxt), 0.05);

        EXEC util.usp_GetConfig @ParamKey = 'journal.ic.markup.pct',
             @Default = '0.03', @Value = @icPctTxt OUTPUT;
        SET @icPct = ISNULL(TRY_CONVERT(DECIMAL(9,6), @icPctTxt), 0.03);

        IF @DebugLevel > 0
            PRINT CONCAT('[journal] date=', CONVERT(VARCHAR(10), @BusinessDate),
                         ' mode=', @Mode,
                         ' ic=', @IncludeIntercompany,
                         ' reval=', @FxRevaluation,
                         ' defer=', @DeferUnshipped,
                         ' tol=', @tol);

        /* ========================================================
           SECTION 2 -- fiscal period + period-end detection
           ref.Calendar is built by util.usp_BuildCalendar. On a box
           where the calendar wasn't built far enough forward the
           lookup comes back NULL, and we fall back to calendar
           month, which is right for 10 months of the year and wrong
           for the two where finance shifts the close.
           ======================================================== */

        SELECT @fiscalYear   = FiscalYear,
               @fiscalPeriod = FiscalPeriod
          FROM ref.Calendar
         WHERE CalendarDate = @BusinessDate;

        IF @fiscalYear IS NULL
        BEGIN
            SET @fiscalYear   = YEAR(@BusinessDate);
            SET @fiscalPeriod = MONTH(@BusinessDate);
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                    CONCAT('no ref.Calendar row for ', CONVERT(VARCHAR(10), @BusinessDate),
                           ' -- fell back to calendar month. Run util.usp_BuildCalendar.'));
        END

        /* period end = last day of the fiscal period we can see in
           the calendar. If the calendar is missing, use month end. */
        IF NOT EXISTS (
            SELECT 1 FROM ref.Calendar
             WHERE FiscalYear = @fiscalYear AND FiscalPeriod = @fiscalPeriod
               AND CalendarDate > @BusinessDate)
            SET @isPeriodEnd = 1;

        IF @isPeriodEnd = 0 AND @BusinessDate = EOMONTH(@BusinessDate)
            SET @isPeriodEnd = 1;

        /* revaluation is a period-end activity. If someone asked for
           it mid-period, honour it but say so loudly. */
        IF @FxRevaluation = 1 AND @isPeriodEnd = 0
        BEGIN
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                    'FX revaluation requested mid-period -- this will be reversed by the next period-end run');
        END

        /* ========================================================
           SECTION 3 -- re-run guard
           ======================================================== */

        SELECT TOP (1) @priorJournalId = JournalId
          FROM fin.JournalEntry
         WHERE EntryDate = @BusinessDate
           AND Source    = 'SALES'
           AND Status    = 'POSTED'
         ORDER BY JournalId DESC;

        IF @priorJournalId IS NOT NULL
        BEGIN
            IF @ReRun = 0
            BEGIN
                SET @msg = CONCAT('SALES journal ', @priorJournalId,
                                  ' already POSTED for ', CONVERT(VARCHAR(10), @BusinessDate),
                                  '. Pass @ReRun = 1 to supersede it.');
                THROW 55011, 'Sales journal already posted for this date (see ErrorLog for the journal id)', 1;
            END

            /* flip, don't contra. fin.usp_ReverseJournal opens its
               own transaction and calling it from inside the batch
               transaction deadlocked against JournalLine in 2021.
               The contra entry is raised by hand by finance if the
               reversal matters for the period. */
            UPDATE fin.JournalEntry
               SET Status = 'REVERSED'
             WHERE JournalId = @priorJournalId;

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                    CONCAT('superseded journal ', @priorJournalId, ' for ',
                           CONVERT(VARCHAR(10), @BusinessDate),
                           ' -- NO contra entry was posted, raise one manually if the period is closed'));
        END

        /* ========================================================
           SECTION 4 -- working tables
           One per pass. They are dropped defensively at the top
           because a proc that threw halfway through used to leave
           them behind in the session and the next run would insert
           into yesterday's #rev. Session-scoped temp tables, so
           this only matters when the same connection reruns.
           ======================================================== */

        IF OBJECT_ID('tempdb..#ordbase') IS NOT NULL DROP TABLE #ordbase;
        IF OBJECT_ID('tempdb..#rev')     IS NOT NULL DROP TABLE #rev;
        IF OBJECT_ID('tempdb..#cogs')    IS NOT NULL DROP TABLE #cogs;
        IF OBJECT_ID('tempdb..#ic')      IS NOT NULL DROP TABLE #ic;
        IF OBJECT_ID('tempdb..#defer')   IS NOT NULL DROP TABLE #defer;
        IF OBJECT_ID('tempdb..#reval')   IS NOT NULL DROP TABLE #reval;
        IF OBJECT_ID('tempdb..#jl')      IS NOT NULL DROP TABLE #jl;

        CREATE TABLE #ordbase (
            OrderId       INT           NOT NULL PRIMARY KEY,
            CustomerId    INT           NOT NULL,
            CurrencyCode  CHAR(3)       NOT NULL,
            WarehouseId   INT           NULL,
            Basis         VARCHAR(10)   NOT NULL,   -- ACCRUAL|CASH
            NetLocal      DECIMAL(18,4) NOT NULL,
            TaxLocal      DECIMAL(18,4) NOT NULL,
            ShipLocal     DECIMAL(18,4) NOT NULL,
            GrandLocal    DECIMAL(18,4) NOT NULL,
            OrderStatus   VARCHAR(20)   NOT NULL
        );

        CREATE TABLE #rev (
            OrderId       INT           NOT NULL PRIMARY KEY,
            CurrencyCode  CHAR(3)       NOT NULL,
            RateUsed      DECIMAL(18,8) NULL,
            NetUsd        DECIMAL(18,4) NOT NULL,
            TaxUsd        DECIMAL(18,4) NOT NULL,
            ShipUsd       DECIMAL(18,4) NOT NULL,
            GrandUsd      DECIMAL(18,4) NOT NULL,
            RateMissing   BIT           NOT NULL DEFAULT 0
        );

        CREATE TABLE #cogs (
            ProductId     INT           NOT NULL,
            WarehouseId   INT           NOT NULL,
            UnitsShipped  INT           NOT NULL,
            UnitsReturned INT           NOT NULL,
            CostShipped   DECIMAL(18,4) NOT NULL,
            CostReturned  DECIMAL(18,4) NOT NULL
        );

        CREATE TABLE #ic (
            OrderId       INT           NOT NULL PRIMARY KEY,
            ShipCountry   CHAR(2)       NULL,
            CustCountry   CHAR(2)       NULL,
            NetUsd        DECIMAL(18,4) NOT NULL,
            GrandUsd      DECIMAL(18,4) NOT NULL,
            MarkupUsd     DECIMAL(18,4) NOT NULL
        );

        CREATE TABLE #defer (
            OrderId       INT           NOT NULL PRIMARY KEY,
            NetUsd        DECIMAL(18,4) NOT NULL,
            PaidUtc       DATETIME2(3)  NULL
        );

        CREATE TABLE #reval (
            CurrencyCode  CHAR(3)       NOT NULL PRIMARY KEY,
            OpenArLocal   DECIMAL(18,4) NOT NULL,
            BookedRate    DECIMAL(18,8) NULL,
            PeriodEndRate DECIMAL(18,8) NULL,
            DeltaUsd      DECIMAL(18,4) NOT NULL
        );

        /* the journal accumulator. Everything above ends up here as
           account/debit/credit triples and section 12 turns it into
           a @LineSpec string. */
        CREATE TABLE #jl (
            Seq           INT IDENTITY(1,1) PRIMARY KEY,
            AccountCode   VARCHAR(20)   NOT NULL,
            DebitAmount   DECIMAL(18,4) NOT NULL DEFAULT 0,
            CreditAmount  DECIMAL(18,4) NOT NULL DEFAULT 0,
            Note          VARCHAR(200)  NULL
        );

        /* ========================================================
           SECTION 5 -- in-scope orders, by mode
           ======================================================== */

        IF @Mode IN ('ACCRUAL','BOTH')
        BEGIN
            INSERT INTO #ordbase
                (OrderId, CustomerId, CurrencyCode, WarehouseId, Basis,
                 NetLocal, TaxLocal, ShipLocal, GrandLocal, OrderStatus)
            SELECT oh.OrderId,
                   oh.CustomerId,
                   oh.CurrencyCode,
                   oh.WarehouseId,
                   'ACCRUAL',
                   (oh.SubTotal - oh.DiscountTotal),
                   oh.TaxTotal,
                   oh.ShippingTotal,
                   oh.GrandTotal,
                   oh.Status
              FROM sales.OrderHeader oh
             WHERE CAST(oh.ModifiedUtc AS DATE) = @BusinessDate
               AND oh.Status IN ('PAID','SHIPPED','COMPLETED');

            SET @orderCount = @@ROWCOUNT;

            IF @DebugLevel > 0 PRINT CONCAT('[journal] accrual orders: ', @orderCount);
        END

        IF @Mode IN ('CASH','BOTH')
        BEGIN
            /* cash basis is driven off the payment, not the order.
               An order can appear here with status NEW if a payment
               was captured before confirmation, which happens with
               the store-credit flow. */
            INSERT INTO #ordbase
                (OrderId, CustomerId, CurrencyCode, WarehouseId, Basis,
                 NetLocal, TaxLocal, ShipLocal, GrandLocal, OrderStatus)
            SELECT oh.OrderId,
                   oh.CustomerId,
                   oh.CurrencyCode,
                   oh.WarehouseId,
                   'CASH',
                   (oh.SubTotal - oh.DiscountTotal),
                   oh.TaxTotal,
                   oh.ShippingTotal,
                   oh.GrandTotal,
                   oh.Status
              FROM sales.OrderHeader oh
             WHERE EXISTS (
                       SELECT 1 FROM sales.Payment p
                        WHERE p.OrderId = oh.OrderId
                          AND CAST(p.ProcessedUtc AS DATE) = @BusinessDate
                          AND p.Status IN ('CAPTURED','REFUNDED'))
               /* ... and not already in from the accrual pass. This
                  is the FIN-412 double-count guard and it is only
                  half a guard: it dedupes on OrderId, so an order in
                  both bases is counted once on the ACCRUAL basis and
                  its cash timing difference is silently dropped. */
               AND NOT EXISTS (SELECT 1 FROM #ordbase b WHERE b.OrderId = oh.OrderId);

            IF @DebugLevel > 0 PRINT CONCAT('[journal] cash orders added: ', @@ROWCOUNT);
        END

        SELECT @orderCount = COUNT(*) FROM #ordbase;

        /* ========================================================
           SECTION 6 -- per-order FX conversion
           RBAR because dbo.usp_ConvertCurrency is a proc, not a
           function, and you cannot call a proc from a SELECT. This
           is the single slowest thing in the nightly batch. The
           set-based rewrite is FIN-118 and has been "next sprint"
           since 2020.

           Note we convert each component separately and round each
           one. That is what makes the plug in section 11 necessary.
           Converting the grand total and apportioning would round
           once, but would change every historical number, so it
           stays as it is.
           ======================================================== */

        DECLARE @oid INT, @ccy CHAR(3), @netL DECIMAL(18,4), @taxL DECIMAL(18,4),
                @shipL DECIMAL(18,4), @grandL DECIMAL(18,4);
        DECLARE @netU DECIMAL(18,4), @taxU DECIMAL(18,4),
                @shipU DECIMAL(18,4), @grU DECIMAL(18,4);
        DECLARE @rateUsed DECIMAL(18,8), @rateMissing BIT;

        DECLARE ord_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT OrderId, CurrencyCode, NetLocal, TaxLocal, ShipLocal, GrandLocal
              FROM #ordbase
             ORDER BY OrderId;
        OPEN ord_cur;
        FETCH NEXT FROM ord_cur INTO @oid, @ccy, @netL, @taxL, @shipL, @grandL;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @rateMissing = 0;
            SET @rateUsed    = NULL;

            /* usp_ConvertCurrency returns 1 when it could not find a
               rate and passed the amount through unconverted. We
               check the return code here. We do NOT check it in the
               deferral or revaluation passes below, which is an
               inconsistency nobody has justified. */
            EXEC @rc = dbo.usp_ConvertCurrency
                 @Amount = @netL, @FromCurrency = @ccy, @ToCurrency = 'USD',
                 @AsOfDate = @BusinessDate, @Result = @netU OUTPUT;
            IF @rc = 1 SET @rateMissing = 1;

            EXEC dbo.usp_ConvertCurrency
                 @Amount = @taxL, @FromCurrency = @ccy, @ToCurrency = 'USD',
                 @AsOfDate = @BusinessDate, @Result = @taxU OUTPUT;

            EXEC dbo.usp_ConvertCurrency
                 @Amount = @shipL, @FromCurrency = @ccy, @ToCurrency = 'USD',
                 @AsOfDate = @BusinessDate, @Result = @shipU OUTPUT;

            EXEC dbo.usp_ConvertCurrency
                 @Amount = @grandL, @FromCurrency = @ccy, @ToCurrency = 'USD',
                 @AsOfDate = @BusinessDate, @Result = @grU OUTPUT;

            /* reconstruct the effective rate for the audit trail.
               Divide-by-zero guarded because a zero-value order is
               legal (100% discount staff orders). */
            IF @ccy = 'USD'
                SET @rateUsed = 1.0;
            ELSE IF @netL <> 0
                SET @rateUsed = ROUND(@netU / @netL, 8);

            INSERT INTO #rev (OrderId, CurrencyCode, RateUsed, NetUsd, TaxUsd, ShipUsd, GrandUsd, RateMissing)
            VALUES (@oid, @ccy, @rateUsed, @netU, @taxU, @shipU, @grU, @rateMissing);

            IF @rateMissing = 1 SET @noRateCount = @noRateCount + 1;

            FETCH NEXT FROM ord_cur INTO @oid, @ccy, @netL, @taxL, @shipL, @grandL;
        END
        CLOSE ord_cur; DEALLOCATE ord_cur;

        SELECT @totalNet   = ISNULL(SUM(NetUsd),0),
               @totalTax   = ISNULL(SUM(TaxUsd),0),
               @totalShip  = ISNULL(SUM(ShipUsd),0),
               @totalGrand = ISNULL(SUM(GrandUsd),0)
          FROM #rev;

        IF @noRateCount > 0
        BEGIN
            /* this understates revenue by whatever the missing rate
               would have done. It is logged, never blocked -- the
               2018 decision was that a late FX feed should not stop
               the close. etl.usp_LoadFxRates silently no-opping is
               the usual cause. */
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                    CONCAT(@noRateCount, ' order(s) had no FX rate on ',
                           CONVERT(VARCHAR(10), @BusinessDate),
                           ' and were booked 1:1. Revenue is understated.'));
        END

        IF @DebugLevel > 1
            SELECT 'rev' AS Section, * FROM #rev ORDER BY OrderId;

        /* ========================================================
           SECTION 7 -- COGS
           Cost of goods actually shipped on the date, from the
           movement ledger rather than the order lines, because the
           ledger carries the cost at the moment of shipment and
           dbo.Product.UnitCost drifts.

           SHIP movements are stored negative; RETURN movements
           positive. Returns reduce COGS on the day they are
           restocked, which is not the day the return was raised.
           ======================================================== */

        INSERT INTO #cogs (ProductId, WarehouseId, UnitsShipped, UnitsReturned, CostShipped, CostReturned)
        SELECT sm.ProductId,
               sm.WarehouseId,
               SUM(CASE WHEN sm.MovementType = 'SHIP'   THEN ABS(sm.Qty) ELSE 0 END),
               SUM(CASE WHEN sm.MovementType = 'RETURN' THEN ABS(sm.Qty) ELSE 0 END),
               SUM(CASE WHEN sm.MovementType = 'SHIP'
                        THEN ABS(sm.Qty) * ISNULL(sm.UnitCost, 0) ELSE 0 END),
               SUM(CASE WHEN sm.MovementType = 'RETURN'
                        THEN ABS(sm.Qty) * ISNULL(sm.UnitCost, 0) ELSE 0 END)
          FROM inv.StockMovement sm
         WHERE CAST(sm.CreatedUtc AS DATE) = @BusinessDate
           AND sm.MovementType IN ('SHIP','RETURN')
         GROUP BY sm.ProductId, sm.WarehouseId;

        /* movements with a NULL UnitCost contribute zero cost and
           silently understate COGS. That is usually a movement
           posted by hand through inv.usp_PostStockMovement without
           a cost. Flag them, don't fix them. */
        IF EXISTS (SELECT 1 FROM inv.StockMovement
                    WHERE CAST(CreatedUtc AS DATE) = @BusinessDate
                      AND MovementType IN ('SHIP','RETURN')
                      AND UnitCost IS NULL)
        BEGIN
            SELECT @msg = CONCAT(COUNT(*), ' movement(s) on ',
                                 CONVERT(VARCHAR(10), @BusinessDate),
                                 ' have no UnitCost -- COGS understated')
              FROM inv.StockMovement
             WHERE CAST(CreatedUtc AS DATE) = @BusinessDate
               AND MovementType IN ('SHIP','RETURN')
               AND UnitCost IS NULL;

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0, @msg);
        END

        SELECT @cogs         = ISNULL(SUM(CostShipped), 0),
               @cogsReturned = ISNULL(SUM(CostReturned), 0)
          FROM #cogs;

        /* net COGS. Returns can exceed shipments on a quiet day
           after a big return batch, which makes this negative and
           flips the DR/CR sides in section 11. */
        SET @cogs = @cogs - @cogsReturned;

        IF @DebugLevel > 0
            PRINT CONCAT('[journal] cogs=', @cogs, ' (returns ', @cogsReturned, ')');

        /* ========================================================
           SECTION 8 -- nothing to do?
           Checked after COGS so that a day with returns but no
           sales still posts.
           ======================================================== */

        IF @totalGrand = 0 AND @cogs = 0 AND @orderCount = 0
        BEGIN
            EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = 0, @Message = 'no activity';
            RETURN 0;
        END

        /* ========================================================
           SECTION 9 -- intercompany split
           An order is intercompany when the warehouse it shipped
           from sits in a different country to the customer. Both
           sides are nullable, and NULL is treated as domestic --
           which means every order with no warehouse (i.e. anything
           that never got past NEW, and anything imported before the
           2019 warehouse backfill) is quietly domestic.
           ======================================================== */

        IF @IncludeIntercompany = 1
        BEGIN
            INSERT INTO #ic (OrderId, ShipCountry, CustCountry, NetUsd, GrandUsd, MarkupUsd)
            SELECT r.OrderId,
                   w.CountryCode,
                   c.CountryCode,
                   r.NetUsd,
                   r.GrandUsd,
                   ROUND(r.NetUsd * @icPct, 4)
              FROM #rev r
              JOIN #ordbase b ON b.OrderId = r.OrderId
              LEFT JOIN inv.Warehouse w ON w.WarehouseId = b.WarehouseId
              LEFT JOIN dbo.Customer  c ON c.CustomerId  = b.CustomerId
             WHERE w.CountryCode IS NOT NULL
               AND c.CountryCode IS NOT NULL
               AND w.CountryCode <> c.CountryCode;

            SELECT @icNet    = ISNULL(SUM(NetUsd), 0),
                   @icGrand  = ISNULL(SUM(GrandUsd), 0),
                   @icMarkup = ISNULL(SUM(MarkupUsd), 0)
              FROM #ic;

            IF @DebugLevel > 0
                PRINT CONCAT('[journal] intercompany: ',
                             (SELECT COUNT(*) FROM #ic), ' orders, net ', @icNet,
                             ', markup ', @icMarkup);

            /* the intercompany orders are still in #rev and still
               in the base totals. Section 11 backs them out of 4000
               and 1200 rather than excluding them earlier, because
               the base entry has to tie to the order set for the
               reconciliation cross-check to work. */
        END

        /* ========================================================
           SECTION 10 -- deferred revenue
           PAID with no shipment row. Note this uses the shipment
           table, not OrderLine.QtyShipped -- the two disagree on
           partially shipped orders and this pass treats a partial
           shipment as fully earned.
           ======================================================== */

        IF @DeferUnshipped = 1
        BEGIN
            INSERT INTO #defer (OrderId, NetUsd, PaidUtc)
            SELECT r.OrderId,
                   r.NetUsd,
                   (SELECT MAX(p.ProcessedUtc) FROM sales.Payment p
                     WHERE p.OrderId = r.OrderId AND p.Status = 'CAPTURED')
              FROM #rev r
              JOIN #ordbase b ON b.OrderId = r.OrderId
             WHERE b.OrderStatus = 'PAID'
               AND NOT EXISTS (SELECT 1 FROM sales.Shipment s
                                WHERE s.OrderId = r.OrderId
                                  AND s.Status IN ('SHIPPED','DELIVERED'));

            SELECT @deferNet = ISNULL(SUM(NetUsd), 0) FROM #defer;

            /* the deferral is a balance, not a movement, but we post
               entries not balances -- so we book the delta against
               whatever we deferred last time. Reading the prior
               journal to work out "last time" is FIN-503 and it is
               as fragile as it looks: if last night's journal was
               reversed, or the deferral flag was off, the delta is
               computed against zero and the whole balance is
               re-deferred. */
            SELECT @priorDeferBal = ISNULL(SUM(jl.CreditAmount - jl.DebitAmount), 0)
              FROM fin.JournalEntry je
              JOIN fin.JournalLine  jl ON jl.JournalId = je.JournalId
              JOIN fin.GLAccount    ga ON ga.GLAccountId = jl.GLAccountId
             WHERE je.Source    = 'SALES'
               AND je.Status    = 'POSTED'
               AND je.EntryDate = DATEADD(DAY, -1, @BusinessDate)
               AND ga.AccountCode = '2400';

            SET @deferDelta = @deferNet - @priorDeferBal;

            IF @DebugLevel > 0
                PRINT CONCAT('[journal] defer balance=', @deferNet,
                             ' prior=', @priorDeferBal, ' delta=', @deferDelta);
        END

        /* ========================================================
           SECTION 11 -- FX revaluation
           Period end only. Revalue the open receivable per currency
           from the rate it was booked at to the period-end rate.
           "Open" here means orders that are PAID or SHIPPED but not
           COMPLETED, which is an approximation of an aged AR
           balance and is not what the AR subledger would say.
           ======================================================== */

        IF @FxRevaluation = 1
        BEGIN
            DECLARE @rcur CHAR(3), @openLocal DECIMAL(18,4),
                    @bookRate DECIMAL(18,8), @endRate DECIMAL(18,8),
                    @openUsdAtBook DECIMAL(18,4), @openUsdAtEnd DECIMAL(18,4);

            DECLARE ccy_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT oh.CurrencyCode,
                       SUM(oh.GrandTotal - oh.PaidAmount)
                  FROM sales.OrderHeader oh
                 WHERE oh.Status IN ('PAID','SHIPPED')
                   AND oh.CurrencyCode <> 'USD'
                   AND CAST(oh.OrderDate AS DATE) <= @BusinessDate
                 GROUP BY oh.CurrencyCode
                HAVING SUM(oh.GrandTotal - oh.PaidAmount) <> 0;

            OPEN ccy_cur;
            FETCH NEXT FROM ccy_cur INTO @rcur, @openLocal;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                /* period-end rate */
                SELECT TOP (1) @endRate = Rate
                  FROM ref.FxRate
                 WHERE FromCurrency = @rcur AND ToCurrency = 'USD'
                   AND RateDate <= @BusinessDate
                 ORDER BY RateDate DESC;

                /* "booked at" rate. Properly this is a weighted
                   average of the rates each order was booked at.
                   What it actually is: the rate 30 days before the
                   business date, because that was easier and
                   somebody signed it off in 2020. */
                SELECT TOP (1) @bookRate = Rate
                  FROM ref.FxRate
                 WHERE FromCurrency = @rcur AND ToCurrency = 'USD'
                   AND RateDate <= DATEADD(DAY, -30, @BusinessDate)
                 ORDER BY RateDate DESC;

                IF @endRate IS NOT NULL AND @bookRate IS NOT NULL
                BEGIN
                    SET @openUsdAtBook = ROUND(@openLocal * @bookRate, 4);
                    SET @openUsdAtEnd  = ROUND(@openLocal * @endRate,  4);

                    INSERT INTO #reval (CurrencyCode, OpenArLocal, BookedRate, PeriodEndRate, DeltaUsd)
                    VALUES (@rcur, @openLocal, @bookRate, @endRate,
                            @openUsdAtEnd - @openUsdAtBook);
                END
                ELSE
                BEGIN
                    INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                    VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                            CONCAT('revaluation skipped for ', @rcur,
                                   ' -- missing period-end or booked rate'));
                END

                SET @endRate  = NULL;
                SET @bookRate = NULL;

                FETCH NEXT FROM ccy_cur INTO @rcur, @openLocal;
            END
            CLOSE ccy_cur; DEALLOCATE ccy_cur;

            SELECT @revalGain = ISNULL(SUM(CASE WHEN DeltaUsd > 0 THEN DeltaUsd ELSE 0 END), 0),
                   @revalLoss = ISNULL(SUM(CASE WHEN DeltaUsd < 0 THEN ABS(DeltaUsd) ELSE 0 END), 0)
              FROM #reval;

            IF @DebugLevel > 0
                PRINT CONCAT('[journal] reval gain=', @revalGain, ' loss=', @revalLoss);
        END

        /* ========================================================
           SECTION 12 -- assemble the journal lines
           Order matters only for readability of the posted entry;
           fin.usp_PostJournalEntry aggregates by account anyway.
           ======================================================== */

        /* --- base revenue --- */
        INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
        VALUES ('1200', @totalGrand, 0, 'AR - daily sales');

        INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
        VALUES ('4000', 0, @totalNet, 'Sales revenue net of tax');

        INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
        VALUES ('2200', 0, @totalTax, 'Sales tax collected');

        /* shipping revenue is credited to 4000 as well. Finance has
           asked for a separate freight account three times. */

        /* --- intercompany reclass --- */
        IF @IncludeIntercompany = 1 AND @icGrand <> 0
        BEGIN
            /* move the receivable */
            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('1210', @icGrand, 0, 'AR intercompany reclass');

            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('1200', 0, @icGrand, 'AR intercompany reclass (contra)');

            /* move the revenue */
            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('4000', @icNet, 0, 'IC revenue reclass (contra)');

            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('4100', 0, @icNet, 'Intercompany revenue');

            /* the markup. Debits the receivable, credits IC revenue.
               Not eliminated -- see the header. */
            IF @icMarkup <> 0
            BEGIN
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('1210', @icMarkup, 0, 'IC transfer markup');

                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('4100', 0, @icMarkup, 'IC transfer markup');
            END
        END

        /* --- deferral --- */
        IF @DeferUnshipped = 1 AND @deferDelta <> 0
        BEGIN
            IF @deferDelta > 0
            BEGIN
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('4000', @deferDelta, 0, 'Defer unshipped revenue');

                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('2400', 0, @deferDelta, 'Deferred revenue');
            END
            ELSE
            BEGIN
                /* release */
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('2400', ABS(@deferDelta), 0, 'Release deferred revenue');

                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('4000', 0, ABS(@deferDelta), 'Release deferred revenue');
            END
        END

        /* --- COGS --- */
        IF @cogs > 0
        BEGIN
            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('5000', @cogs, 0, 'COGS shipped');

            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('1300', 0, @cogs, 'Inventory relieved');
        END
        ELSE IF @cogs < 0
        BEGIN
            /* net returns exceeded shipments */
            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('1300', ABS(@cogs), 0, 'Inventory restocked (net returns)');

            INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
            VALUES ('5000', 0, ABS(@cogs), 'COGS credit (net returns)');
        END

        /* --- FX revaluation --- */
        IF @FxRevaluation = 1
        BEGIN
            IF @revalGain <> 0
            BEGIN
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('1200', @revalGain, 0, 'FX revaluation gain');

                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('6900', 0, @revalGain, 'FX revaluation gain');
            END

            IF @revalLoss <> 0
            BEGIN
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('6900', @revalLoss, 0, 'FX revaluation loss');

                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('1200', 0, @revalLoss, 'FX revaluation loss');
            END
        END

        /* ========================================================
           SECTION 13 -- the rounding sweep
           The entry will not balance, because every amount above
           was rounded independently after an FX conversion. Work
           out the residual and plug it into 9999.

           Then redistribute: if the plug is larger than a penny per
           order we push the excess back onto the largest-value
           orders a penny at a time, so that the suspense account
           stays small and the per-order numbers stay defensible.
           This loop is the reason the journal is not reproducible
           if #rev is ordered differently -- ties are broken by
           OrderId only after GrandUsd, and equal-value orders swap
           places between runs on a parallel plan.
           ======================================================== */

        SELECT @drTotal = ISNULL(SUM(DebitAmount), 0),
               @crTotal = ISNULL(SUM(CreditAmount), 0)
          FROM #jl;

        SET @plug = @drTotal - @crTotal;

        IF @DebugLevel > 0
            PRINT CONCAT('[journal] dr=', @drTotal, ' cr=', @crTotal, ' plug=', @plug);

        IF ABS(@plug) > @tol
        BEGIN
            /* too big to be rounding. Something is actually wrong --
               most often a missing FX rate on a large order, or a
               COGS movement with a NULL cost. Log the detail and
               refuse to post. */
            SET @msg = CONCAT('Sales journal for ', CONVERT(VARCHAR(10), @BusinessDate),
                              ' out of balance by ', @plug,
                              ' which exceeds tolerance ', @tol,
                              '. dr=', @drTotal, ' cr=', @crTotal,
                              ' orders=', @orderCount, ' norate=', @noRateCount);

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 55012, @msg);

            THROW 55012, 'Sales journal out of balance beyond tolerance -- see util.ErrorLog', 1;
        END

        IF @plug <> 0
        BEGIN
            /* residual within tolerance. Plug it. */
            IF @plug > 0
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('9999', 0, @plug, 'FX rounding residual');
            ELSE
                INSERT INTO #jl (AccountCode, DebitAmount, CreditAmount, Note)
                VALUES ('9999', ABS(@plug), 0, 'FX rounding residual');

            /* penny redistribution. Only kicks in when the residual
               is worth more than a penny per in-scope order --
               below that, leaving it in suspense is cheaper than
               explaining it. */
            DECLARE @pennies INT = CAST(ROUND(ABS(@plug) * 100, 0) AS INT);
            DECLARE @spread  INT = 0;

            IF @orderCount > 0 AND @pennies > @orderCount
            BEGIN
                DECLARE @targetOrder INT, @targetVal DECIMAL(18,4);

                DECLARE plug_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT TOP (100) OrderId, GrandUsd
                      FROM #rev
                     ORDER BY GrandUsd DESC, OrderId;   -- tie-break is not stable enough. FIN-260.
                OPEN plug_cur;
                FETCH NEXT FROM plug_cur INTO @targetOrder, @targetVal;

                WHILE @@FETCH_STATUS = 0 AND @pennies > 0
                BEGIN
                    /* one penny per order, largest first, until the
                       residual is gone or we run out of orders */
                    UPDATE #rev
                       SET GrandUsd = GrandUsd + CASE WHEN @plug > 0 THEN -0.01 ELSE 0.01 END
                     WHERE OrderId = @targetOrder;

                    SET @pennies = @pennies - 1;
                    SET @spread  = @spread + 1;

                    FETCH NEXT FROM plug_cur INTO @targetOrder, @targetVal;
                END
                CLOSE plug_cur; DEALLOCATE plug_cur;

                IF @DebugLevel > 0
                    PRINT CONCAT('[journal] redistributed ', @spread,
                                 ' penny adjustments, ', @pennies, ' left in suspense');

                /* NOTE: #rev is adjusted but #jl is NOT recomputed.
                   The redistribution changes the per-order audit
                   trail without changing the posted totals, which
                   is either the point or a bug depending on who you
                   ask. FIN-260 has both opinions in the comments. */
            END
        END

        /* ========================================================
           SECTION 14 -- collapse to a spec string
           fin.usp_PostJournalEntry takes
              'acct:debit:credit,acct:debit:credit,...'
           so we aggregate #jl by account and flatten it. Same
           STUFF/FOR XML PATH pattern as inv.usp_RunReorder --
           STRING_AGG would be cleaner but this has to run on the
           2016 box in the DR site.
           ======================================================== */

        ;WITH byAcct AS (
            SELECT AccountCode,
                   SUM(DebitAmount)  AS dr,
                   SUM(CreditAmount) AS cr
              FROM #jl
             GROUP BY AccountCode
        ),
        netted AS (
            /* net each account down to a single side. An account
               that nets to zero is dropped entirely rather than
               posted as 0:0 -- finance does not want to see the
               intercompany contra lines when there is no
               intercompany activity. */
            SELECT AccountCode,
                   CASE WHEN dr - cr > 0 THEN dr - cr ELSE 0 END AS drNet,
                   CASE WHEN cr - dr > 0 THEN cr - dr ELSE 0 END AS crNet
              FROM byAcct
        )
        SELECT @spec = STUFF((
            SELECT ',' + AccountCode
                       + ':' + CONVERT(VARCHAR(20), CAST(drNet AS DECIMAL(18,4)))
                       + ':' + CONVERT(VARCHAR(20), CAST(crNet AS DECIMAL(18,4)))
              FROM netted
             WHERE drNet <> 0 OR crNet <> 0
             ORDER BY AccountCode
             FOR XML PATH('')), 1, 1, '');

        IF @spec IS NULL OR LTRIM(RTRIM(@spec)) = ''
        BEGIN
            EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = 0,
                 @Message = 'nothing to post after netting';
            RETURN 0;
        END

        IF @DebugLevel > 0 PRINT CONCAT('[journal] spec=', @spec);

        /* ========================================================
           SECTION 15 -- post
           ======================================================== */

        IF @WhatIf = 1
        BEGIN
            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                    CONCAT('WHATIF ', CONVERT(VARCHAR(10), @BusinessDate), ' spec=', LEFT(@spec, 3500)));

            EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @orderCount,
                 @Message = CONCAT('whatif only, mode ', @Mode);
            RETURN 0;
        END

        EXEC fin.usp_PostJournalEntry
             @EntryDate   = @BusinessDate,
             @Source      = 'SALES',
             @Description = 'Daily sales',
             @LineSpec    = @spec,
             @BatchId     = @BatchId,
             @JournalId   = @jid OUTPUT;

        /* ========================================================
           SECTION 16 -- 'BOTH' timing-difference entry
           The difference between what the accrual basis recognised
           and what cash actually landed. Posted as a separate
           entry so it can be reversed on its own.

           Only the orders that came in on the CASH basis are in
           scope here, which -- because of the NOT EXISTS dedupe in
           section 5 -- excludes exactly the orders the timing
           difference is about. This entry is therefore almost
           always zero and almost always wrong. FIN-412.
           ======================================================== */

        IF @Mode = 'BOTH'
        BEGIN
            DECLARE @cashNet DECIMAL(18,4), @accrualNet DECIMAL(18,4), @timingDiff DECIMAL(18,4);

            SELECT @cashNet = ISNULL(SUM(r.NetUsd), 0)
              FROM #rev r JOIN #ordbase b ON b.OrderId = r.OrderId
             WHERE b.Basis = 'CASH';

            SELECT @accrualNet = ISNULL(SUM(r.NetUsd), 0)
              FROM #rev r JOIN #ordbase b ON b.OrderId = r.OrderId
             WHERE b.Basis = 'ACCRUAL';

            SET @timingDiff = @cashNet - @accrualNet;

            IF ABS(@timingDiff) > 0.005
            BEGIN
                SET @timingSpec =
                    CASE WHEN @timingDiff > 0
                         THEN CONCAT('1200:', CONVERT(VARCHAR(20), @timingDiff), ':0',
                                     ',4000:0:', CONVERT(VARCHAR(20), @timingDiff))
                         ELSE CONCAT('4000:', CONVERT(VARCHAR(20), ABS(@timingDiff)), ':0',
                                     ',1200:0:', CONVERT(VARCHAR(20), ABS(@timingDiff)))
                    END;

                EXEC fin.usp_PostJournalEntry
                     @EntryDate   = @BusinessDate,
                     @Source      = 'SALES',
                     @Description = 'Cash/accrual timing difference',
                     @LineSpec    = @timingSpec,
                     @BatchId     = @BatchId,
                     @JournalId   = @jidTiming OUTPUT;
            END
        END

        /* ========================================================
           SECTION 17 -- post-post verification
           Re-read what we actually wrote rather than trusting the
           variables, and cross-check revenue against the reporting
           table if it has already been built for the date. The two
           are computed completely differently (this proc is USD and
           ModifiedUtc-driven, rpt.usp_BuildDailySales is order
           currency and OrderDate-driven) so they are NOT expected
           to match -- but a variance of more than a few percent
           usually means one of them ran against the wrong date.
           This is a warning, never a failure. RPT-31.
           ======================================================== */

        SELECT @drTotal = ISNULL(SUM(jl.DebitAmount), 0),
               @crTotal = ISNULL(SUM(jl.CreditAmount), 0)
          FROM fin.JournalLine jl
         WHERE jl.JournalId = @jid;

        IF ABS(@drTotal - @crTotal) > 0.005
        BEGIN
            /* should be impossible -- usp_PostJournalEntry throws on
               an unbalanced entry -- but it has happened, when an
               account code in the spec did not exist in
               fin.GLAccount and the line was silently dropped by
               the inner join. That is the real failure mode here
               and it is worth the extra read. */
            SET @msg = CONCAT('journal ', @jid, ' posted but does not balance: dr=',
                              @drTotal, ' cr=', @crTotal,
                              '. Check every account code in the spec exists in fin.GLAccount.');

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 55013, @msg);

            THROW 55013, 'Posted journal does not balance -- likely an unknown account code', 1;
        END

        IF OBJECT_ID('rpt.DailySalesSummary') IS NOT NULL
        BEGIN
            SELECT @rptNetRevenue = SUM(NetRevenue)
              FROM rpt.DailySalesSummary
             WHERE SummaryDate = @BusinessDate;

            IF @rptNetRevenue IS NOT NULL AND @rptNetRevenue <> 0
               AND ABS(@totalNet - @rptNetRevenue) / ABS(@rptNetRevenue) > 0.05
            BEGIN
                INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                VALUES (@BatchId, 'fin.usp_GenerateSalesJournal', 0,
                        CONCAT('journal net revenue ', @totalNet,
                               ' vs rpt.DailySalesSummary ', @rptNetRevenue,
                               ' for ', CONVERT(VARCHAR(10), @BusinessDate),
                               ' -- >5% variance. Expected (currency basis differs) but check the dates.'));
            END
        END

        /* ========================================================
           SECTION 18 -- done
           ======================================================== */

        SET @msg = CONCAT('journal ', @jid,
                          ' mode ', @Mode,
                          ' orders ', @orderCount,
                          ' net ', @totalNet,
                          ' tax ', @totalTax,
                          ' cogs ', @cogs,
                          CASE WHEN @icGrand <> 0 THEN CONCAT(' ic ', @icNet) ELSE '' END,
                          CASE WHEN @deferDelta <> 0 THEN CONCAT(' defer ', @deferDelta) ELSE '' END,
                          CASE WHEN @plug <> 0 THEN CONCAT(' plug ', @plug) ELSE '' END,
                          CASE WHEN @jidTiming IS NOT NULL THEN CONCAT(' timing ', @jidTiming) ELSE '' END);

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @orderCount, @Message = @msg;

        IF OBJECT_ID('tempdb..#ordbase') IS NOT NULL DROP TABLE #ordbase;
        IF OBJECT_ID('tempdb..#rev')     IS NOT NULL DROP TABLE #rev;
        IF OBJECT_ID('tempdb..#cogs')    IS NOT NULL DROP TABLE #cogs;
        IF OBJECT_ID('tempdb..#ic')      IS NOT NULL DROP TABLE #ic;
        IF OBJECT_ID('tempdb..#defer')   IS NOT NULL DROP TABLE #defer;
        IF OBJECT_ID('tempdb..#reval')   IS NOT NULL DROP TABLE #reval;
        IF OBJECT_ID('tempdb..#jl')      IS NOT NULL DROP TABLE #jl;

        RETURN 0;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ord_cur')  >= 0 BEGIN CLOSE ord_cur;  DEALLOCATE ord_cur;  END
        IF CURSOR_STATUS('local','ccy_cur')  >= 0 BEGIN CLOSE ccy_cur;  DEALLOCATE ccy_cur;  END
        IF CURSOR_STATUS('local','plug_cur') >= 0 BEGIN CLOSE plug_cur; DEALLOCATE plug_cur; END

        IF @@TRANCOUNT > 0 ROLLBACK;

        EXEC util.usp_LogError @ProcName = 'fin.usp_GenerateSalesJournal', @BatchId = @BatchId;
        EXEC util.usp_LogEnd   @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO

/* ============================================================
   The 2019 single-currency version. Kept because FIN-260 is still
   open and every few months somebody asks what the numbers looked
   like before the per-component conversion went in. If you are
   here to answer that question: the difference is that this one
   converted the grand total once and apportioned net/tax out of
   it, so it always balanced to the penny and never needed 9999.
   It was replaced because apportioning tax gave the wrong tax
   liability per jurisdiction, which mattered more than the plug.

   DO NOT re-enable this. It does not know about intercompany,
   deferral or revaluation, and it reads a table (fin.FxRateDaily)
   that was dropped in 2021.

CREATE OR ALTER PROCEDURE fin.usp_GenerateSalesJournal_2019
    @BusinessDate DATE,
    @BatchId      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'fin.usp_GenerateSalesJournal_2019',
         @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    DECLARE @rate DECIMAL(18,8), @grand DECIMAL(18,4),
            @net DECIMAL(18,4), @tax DECIMAL(18,4), @cogs DECIMAL(18,4);

    -- one blended rate for the whole day, from a table that no
    -- longer exists
    SELECT @rate = ISNULL(AVG(Rate), 1.0)
      FROM fin.FxRateDaily
     WHERE RateDate = @BusinessDate;

    SELECT @grand = ISNULL(SUM(GrandTotal * @rate), 0),
           @tax   = ISNULL(SUM(TaxTotal   * @rate), 0)
      FROM sales.OrderHeader
     WHERE CAST(OrderDate AS DATE) = @BusinessDate
       AND Status IN ('PAID','SHIPPED','COMPLETED');

    -- apportion: net is whatever is left after tax
    SET @net = @grand - @tax;

    SELECT @cogs = ISNULL(SUM(ABS(Qty) * ISNULL(UnitCost,0) * @rate), 0)
      FROM inv.StockMovement
     WHERE MovementType = 'SHIP'
       AND CAST(CreatedUtc AS DATE) = @BusinessDate;

    DECLARE @spec VARCHAR(MAX) = CONCAT(
        '1200:', @grand, ':0',
        ',4000:0:', @net,
        ',2200:0:', @tax,
        ',5000:', @cogs, ':0',
        ',1300:0:', @cogs);

    DECLARE @jid INT;
    EXEC fin.usp_PostJournalEntry
         @EntryDate = @BusinessDate, @Source = 'SALES',
         @Description = 'Daily sales', @LineSpec = @spec,
         @BatchId = @BatchId, @JournalId = @jid OUTPUT;

    EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = CONCAT('journal ', @jid);
END
   ============================================================ */
