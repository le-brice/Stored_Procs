/* ============================================================
   07_seed_reference.sql
   Minimal seed data so the procs have something to chew on:
   currencies, countries, GL accounts, config params, a couple of
   warehouses. NOT a full data load -- that's the ETL's job.
   ============================================================ */
USE RetailDW;
GO

/* currencies */
MERGE ref.Currency AS t USING (VALUES
    ('USD','US Dollar',2),('GBP','Pound Sterling',2),('EUR','Euro',2),
    ('CAD','Canadian Dollar',2)
) AS s(CurrencyCode,CurrencyName,MinorUnits) ON t.CurrencyCode=s.CurrencyCode
WHEN NOT MATCHED THEN INSERT (CurrencyCode,CurrencyName,MinorUnits) VALUES (s.CurrencyCode,s.CurrencyName,s.MinorUnits);

/* countries */
MERGE ref.Country AS t USING (VALUES
    ('US','United States','NA','USD'),('GB','United Kingdom','EU','GBP'),
    ('IE','Ireland','EU','EUR'),('DE','Germany','EU','EUR'),
    ('FR','France','EU','EUR'),('CA','Canada','NA','CAD')
) AS s(CountryCode,CountryName,Region,DefaultCurrency) ON t.CountryCode=s.CountryCode
WHEN NOT MATCHED THEN INSERT (CountryCode,CountryName,Region,DefaultCurrency)
     VALUES (s.CountryCode,s.CountryName,s.Region,s.DefaultCurrency);

/* GL accounts referenced by the finance procs */
MERGE fin.GLAccount AS t USING (VALUES
    ('1200','Accounts Receivable','ASSET'),
    ('1300','Inventory','ASSET'),
    ('2200','Sales Tax Payable','LIABILITY'),
    ('4000','Sales Revenue','REVENUE'),
    ('5000','Cost of Goods Sold','EXPENSE'),
    ('9999','FX Rounding Suspense','EXPENSE')
) AS s(AccountCode,AccountName,AccountType) ON t.AccountCode=s.AccountCode
WHEN NOT MATCHED THEN INSERT (AccountCode,AccountName,AccountType) VALUES (s.AccountCode,s.AccountName,s.AccountType);

/* warehouses */
MERGE inv.Warehouse AS t USING (VALUES
    ('WH01','Primary DC - NJ','US'),('WH02','UK DC - Reading','GB')
) AS s(WarehouseCode,WarehouseName,CountryCode) ON t.WarehouseCode=s.WarehouseCode
WHEN NOT MATCHED THEN INSERT (WarehouseCode,WarehouseName,CountryCode) VALUES (s.WarehouseCode,s.WarehouseName,s.CountryCode);

/* config params (the procs read these; defaults exist in code too -- drift warning) */
MERGE util.ConfigParam AS t USING (VALUES
    ('default.warehouse.code','WH01','string','default WH for new orders'),
    ('loyalty.points.per.currency.unit','1','decimal','points earned per 1.00 net'),
    ('reorder.default.point','10','int','fallback reorder point'),
    ('reorder.default.qty','50','int','fallback reorder qty'),
    ('stockcount.variance.alert','25','int','units variance before alert'),
    ('recon.tolerance','0.01','decimal','settlement match tolerance'),
    ('settlement.fee.CARD','0.029','decimal','card processor fee'),
    ('settlement.fee.PAYPAL','0.034','decimal','paypal fee'),
    ('settlement.fee.GIFTCARD','0','decimal','no fee'),
    ('settlement.fee.STORECREDIT','0','decimal','no fee')
) AS s(ParamKey,ParamValue,ParamType,Description) ON t.ParamKey=s.ParamKey
WHEN NOT MATCHED THEN INSERT (ParamKey,ParamValue,ParamType,Description)
     VALUES (s.ParamKey,s.ParamValue,s.ParamType,s.Description);
GO

-- build the date dimension out a couple years
EXEC util.usp_BuildCalendar;
GO
