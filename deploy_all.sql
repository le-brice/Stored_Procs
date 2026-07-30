/* ============================================================
   deploy_all.sql
   Runs the whole thing in dependency order against the current
   server. Schema first, then util procs (everything needs the
   logging procs), then the rest in any order, then seed last
   (seed calls util.usp_BuildCalendar so util must exist first).

   Usage (sqlcmd):
       sqlcmd -S <server> -d master -i deploy_all.sql

   NB: relies on :r relative includes, so run it from the repo root
   with SQLCMD mode ON. In SSMS: Query > SQLCMD Mode.
   ============================================================ */
:setvar repo "."

PRINT '--- schema ---';
:r $(repo)\schema\00_create_schemas.sql
:r $(repo)\schema\01_tables_reference.sql
:r $(repo)\schema\02_tables_core.sql
:r $(repo)\schema\03_tables_inventory.sql
:r $(repo)\schema\04_tables_sales.sql
:r $(repo)\schema\05_tables_finance.sql
:r $(repo)\schema\06_tables_staging_rpt.sql

PRINT '--- util procs (load FIRST) ---';
:r $(repo)\procedures\util\usp_LogStart.sql
:r $(repo)\procedures\util\usp_LogEnd.sql
:r $(repo)\procedures\util\usp_LogError.sql
:r $(repo)\procedures\util\usp_GetConfig.sql
:r $(repo)\procedures\util\usp_NextDocNumber.sql
:r $(repo)\procedures\util\usp_BuildCalendar.sql

PRINT '--- pricing ---';
:r $(repo)\procedures\pricing\usp_ConvertCurrency.sql
:r $(repo)\procedures\pricing\usp_GetProductPrice.sql
:r $(repo)\procedures\pricing\usp_GetTaxRate.sql
:r $(repo)\procedures\pricing\usp_ValidatePromotion.sql
:r $(repo)\procedures\pricing\usp_ApplyPromotion.sql

PRINT '--- customer ---';
:r $(repo)\procedures\customer\usp_GetOrCreateLoyaltyAccount.sql
:r $(repo)\procedures\customer\usp_RecalcLoyaltyTier.sql
:r $(repo)\procedures\customer\usp_AccrueLoyalty.sql
:r $(repo)\procedures\customer\usp_UpsertCustomer.sql
:r $(repo)\procedures\customer\usp_MergeCustomers.sql
:r $(repo)\procedures\customer\proc_FixCustomerDupes.sql

PRINT '--- inventory ---';
:r $(repo)\procedures\inventory\usp_PostStockMovement.sql
:r $(repo)\procedures\inventory\usp_AllocateStock.sql
:r $(repo)\procedures\inventory\usp_CreatePurchaseOrder.sql
:r $(repo)\procedures\inventory\usp_ReceivePurchaseOrder.sql
:r $(repo)\procedures\inventory\usp_RunReorder.sql
:r $(repo)\procedures\inventory\usp_TransferStock.sql
:r $(repo)\procedures\inventory\usp_ApplyStockCount.sql

PRINT '--- orders ---';
:r $(repo)\procedures\orders\usp_RecalcOrderTotals.sql
:r $(repo)\procedures\orders\usp_RecalculateOrderTotals_v2.sql
:r $(repo)\procedures\orders\usp_CreateOrder.sql
:r $(repo)\procedures\orders\usp_AddOrderLine.sql
:r $(repo)\procedures\orders\usp_ConfirmOrder.sql
:r $(repo)\procedures\orders\usp_CapturePayment.sql
:r $(repo)\procedures\orders\usp_CreateShipment.sql
:r $(repo)\procedures\orders\usp_CancelOrder.sql
:r $(repo)\procedures\orders\usp_ProcessReturn.sql

PRINT '--- finance ---';
:r $(repo)\procedures\finance\usp_PostJournalEntry.sql
:r $(repo)\procedures\finance\usp_GenerateSalesJournal.sql
:r $(repo)\procedures\finance\usp_GenerateReturnsJournal.sql
:r $(repo)\procedures\finance\usp_BuildSettlement.sql
:r $(repo)\procedures\finance\usp_ReconcileSettlements.sql
:r $(repo)\procedures\finance\usp_ReverseJournal.sql

PRINT '--- reporting ---';
:r $(repo)\procedures\reporting\usp_BuildDailySales.sql
:r $(repo)\procedures\reporting\usp_BuildCustomerLtv.sql
:r $(repo)\procedures\reporting\usp_BuildInventorySnapshot.sql
:r $(repo)\procedures\reporting\usp_TopProductsByRevenue.sql
:r $(repo)\procedures\reporting\usp_LowStockReport.sql
:r $(repo)\procedures\reporting\usp_RefreshAllReports.sql

PRINT '--- etl ---';
:r $(repo)\procedures\etl\usp_LoadCustomers.sql
:r $(repo)\procedures\etl\usp_LoadProducts.sql
:r $(repo)\procedures\etl\usp_LoadFxRates.sql
:r $(repo)\procedures\etl\usp_ImportRawOrders.sql
:r $(repo)\procedures\etl\usp_ReprocessOrder.sql
:r $(repo)\procedures\etl\usp_RunNightlyBatch.sql

PRINT '--- seed (runs after util procs exist) ---';
:r $(repo)\schema\07_seed_reference.sql

PRINT '--- done ---';
GO
