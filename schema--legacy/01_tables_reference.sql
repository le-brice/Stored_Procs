/* ============================================================
   01_tables_reference.sql
   Reference / dimension-ish tables + util plumbing tables.
   ============================================================ */
USE RetailDW;
GO

/* ---------- util plumbing ---------- */

IF OBJECT_ID('util.ConfigParam') IS NULL
CREATE TABLE util.ConfigParam (
    ParamKey      VARCHAR(100)  NOT NULL PRIMARY KEY,
    ParamValue    VARCHAR(400)  NOT NULL,
    ParamType     VARCHAR(20)   NOT NULL DEFAULT 'string',  -- string|int|decimal|bit|date
    Description    VARCHAR(400)  NULL,
    ModifiedUtc   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('util.ProcLog') IS NULL
CREATE TABLE util.ProcLog (
    ProcLogId     BIGINT IDENTITY(1,1) PRIMARY KEY,
    BatchId       UNIQUEIDENTIFIER NULL,
    ProcName      SYSNAME       NOT NULL,
    Status        VARCHAR(20)   NOT NULL,   -- STARTED|SUCCESS|FAILED
    RowsAffected  BIGINT        NULL,
    Message       VARCHAR(2000) NULL,
    StartedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    EndedUtc      DATETIME2(3)  NULL
);
GO

IF OBJECT_ID('util.ErrorLog') IS NULL
CREATE TABLE util.ErrorLog (
    ErrorLogId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    BatchId       UNIQUEIDENTIFIER NULL,
    ProcName      SYSNAME       NULL,
    ErrorNumber   INT           NULL,
    ErrorSeverity INT           NULL,
    ErrorState    INT           NULL,
    ErrorLine     INT           NULL,
    ErrorMessage  VARCHAR(4000) NULL,
    LoggedUtc     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('util.BatchControl') IS NULL
CREATE TABLE util.BatchControl (
    BatchId       UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    BatchName     VARCHAR(100)  NOT NULL,
    BusinessDate  DATE          NOT NULL,
    Status        VARCHAR(20)   NOT NULL,   -- RUNNING|SUCCESS|FAILED
    StartedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    EndedUtc      DATETIME2(3)  NULL
);
GO

/* ---------- reference data ---------- */

IF OBJECT_ID('ref.Country') IS NULL
CREATE TABLE ref.Country (
    CountryCode   CHAR(2)       NOT NULL PRIMARY KEY,
    CountryName   VARCHAR(100)  NOT NULL,
    Region        VARCHAR(50)   NULL,
    DefaultCurrency CHAR(3)     NULL
);
GO

IF OBJECT_ID('ref.Currency') IS NULL
CREATE TABLE ref.Currency (
    CurrencyCode  CHAR(3)       NOT NULL PRIMARY KEY,
    CurrencyName  VARCHAR(60)   NOT NULL,
    MinorUnits    TINYINT       NOT NULL DEFAULT 2
);
GO

IF OBJECT_ID('ref.FxRate') IS NULL
CREATE TABLE ref.FxRate (
    FromCurrency  CHAR(3)       NOT NULL,
    ToCurrency    CHAR(3)       NOT NULL,
    RateDate      DATE          NOT NULL,
    Rate          DECIMAL(18,8) NOT NULL,
    LoadedUtc     DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_FxRate PRIMARY KEY (FromCurrency, ToCurrency, RateDate)
);
GO

-- date dimension, built by util.usp_BuildCalendar
IF OBJECT_ID('ref.Calendar') IS NULL
CREATE TABLE ref.Calendar (
    CalendarDate  DATE          NOT NULL PRIMARY KEY,
    DayOfWeekNum  TINYINT       NOT NULL,
    DayName       VARCHAR(10)   NOT NULL,
    IsWeekend     BIT           NOT NULL,
    MonthNum      TINYINT       NOT NULL,
    MonthName     VARCHAR(10)   NOT NULL,
    QuarterNum    TINYINT       NOT NULL,
    YearNum       SMALLINT      NOT NULL,
    FiscalYear    SMALLINT      NULL,
    FiscalPeriod  TINYINT       NULL,
    IsHoliday     BIT           NOT NULL DEFAULT 0
);
GO
