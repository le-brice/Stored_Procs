/* ============================================================
   00_create_schemas.sql
   Creates the schemas used by RetailDW.
   Idempotent-ish: guarded by IF NOT EXISTS.
   ============================================================ */

IF DB_ID('RetailDW') IS NULL
BEGIN
    PRINT 'RetailDW does not exist on this server. Create it first.';
END
GO

USE RetailDW;
GO

IF SCHEMA_ID('util')  IS NULL EXEC('CREATE SCHEMA util');
IF SCHEMA_ID('ref')   IS NULL EXEC('CREATE SCHEMA ref');
IF SCHEMA_ID('inv')   IS NULL EXEC('CREATE SCHEMA inv');
IF SCHEMA_ID('sales') IS NULL EXEC('CREATE SCHEMA sales');
IF SCHEMA_ID('fin')   IS NULL EXEC('CREATE SCHEMA fin');
IF SCHEMA_ID('stg')   IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('etl')   IS NULL EXEC('CREATE SCHEMA etl');
IF SCHEMA_ID('rpt')   IS NULL EXEC('CREATE SCHEMA rpt');
-- NOTE: customer + product master live in dbo for historical reasons (RMS legacy)
GO
