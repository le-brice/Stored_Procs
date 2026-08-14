/* ============================================================
   05_tables_finance.sql
   GL accounts, journals, settlements, reconciliation.
   ============================================================ */
USE RetailDW;
GO

IF OBJECT_ID('fin.GLAccount') IS NULL
CREATE TABLE fin.GLAccount (
    GLAccountId   INT IDENTITY(1,1) PRIMARY KEY,
    AccountCode   VARCHAR(20)   NOT NULL UNIQUE,
    AccountName   VARCHAR(120)  NOT NULL,
    AccountType   VARCHAR(20)   NOT NULL,   -- ASSET|LIABILITY|REVENUE|EXPENSE|EQUITY
    IsActive      BIT           NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('fin.JournalEntry') IS NULL
CREATE TABLE fin.JournalEntry (
    JournalId     INT IDENTITY(1,1) PRIMARY KEY,
    JournalNo     VARCHAR(20)   NOT NULL UNIQUE,
    EntryDate     DATE          NOT NULL,
    Source        VARCHAR(30)   NOT NULL,   -- SALES|RETURNS|SETTLEMENT|MANUAL|FX
    Description   VARCHAR(200)  NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'DRAFT', -- DRAFT|POSTED|REVERSED
    BatchId       UNIQUEIDENTIFIER NULL,
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('fin.JournalLine') IS NULL
CREATE TABLE fin.JournalLine (
    JournalLineId INT IDENTITY(1,1) PRIMARY KEY,
    JournalId     INT           NOT NULL,
    GLAccountId   INT           NOT NULL,
    DebitAmount   DECIMAL(18,4) NOT NULL DEFAULT 0,
    CreditAmount  DECIMAL(18,4) NOT NULL DEFAULT 0,
    Memo          VARCHAR(200)  NULL,
    CONSTRAINT FK_JL_JE  FOREIGN KEY (JournalId) REFERENCES fin.JournalEntry(JournalId),
    CONSTRAINT FK_JL_GL  FOREIGN KEY (GLAccountId) REFERENCES fin.GLAccount(GLAccountId)
);
GO

IF OBJECT_ID('fin.Settlement') IS NULL
CREATE TABLE fin.Settlement (
    SettlementId  INT IDENTITY(1,1) PRIMARY KEY,
    SettlementDate DATE         NOT NULL,
    PaymentMethod VARCHAR(20)   NOT NULL,
    GrossAmount   DECIMAL(18,4) NOT NULL,
    FeeAmount     DECIMAL(18,4) NOT NULL DEFAULT 0,
    NetAmount     DECIMAL(18,4) NOT NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'OPEN',  -- OPEN|RECONCILED|DISCREPANCY
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('fin.Reconciliation') IS NULL
CREATE TABLE fin.Reconciliation (
    ReconId       INT IDENTITY(1,1) PRIMARY KEY,
    ReconDate     DATE          NOT NULL,
    PaymentMethod VARCHAR(20)   NOT NULL,
    ExpectedAmount DECIMAL(18,4) NOT NULL,
    SettledAmount DECIMAL(18,4) NOT NULL,
    Variance      DECIMAL(18,4) NOT NULL,
    Status        VARCHAR(20)   NOT NULL DEFAULT 'OPEN',  -- OPEN|MATCHED|UNMATCHED
    CreatedUtc    DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
