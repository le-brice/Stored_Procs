/* ============================================================
   dbo.usp_UpsertCustomer
   Insert-or-update a customer keyed on CustomerNo. Used by the ETL
   customer load (etl.usp_LoadCustomers) and by the CSR tool.
   Returns the CustomerId.

   Email is lower-cased + trimmed. Country free-text is mapped to a
   2-char code via a little lookup; unmapped -> NULL (we log it).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_UpsertCustomer
    @CustomerNo  VARCHAR(20),
    @FirstName   VARCHAR(80) = NULL,
    @LastName    VARCHAR(80) = NULL,
    @Email       VARCHAR(200) = NULL,
    @Phone       VARCHAR(40) = NULL,
    @CountryRaw  VARCHAR(60) = NULL,
    @CustomerId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Email = LOWER(LTRIM(RTRIM(@Email)));

    -- map free text country -> code. quick + dirty, extend as needed.
    DECLARE @countryCode CHAR(2) =
        CASE
            WHEN @CountryRaw IS NULL THEN NULL
            WHEN @CountryRaw IN ('United Kingdom','UK','GB','Britain','England') THEN 'GB'
            WHEN @CountryRaw IN ('Ireland','IE','Eire') THEN 'IE'
            WHEN @CountryRaw IN ('United States','USA','US','America') THEN 'US'
            WHEN @CountryRaw IN ('Germany','DE','Deutschland') THEN 'DE'
            WHEN @CountryRaw IN ('France','FR') THEN 'FR'
            WHEN @CountryRaw IN ('Canada','CA') THEN 'CA'
            WHEN LEN(@CountryRaw) = 2 THEN UPPER(@CountryRaw)
            ELSE NULL
        END;

    SELECT @CustomerId = CustomerId FROM dbo.Customer WHERE CustomerNo = @CustomerNo;

    IF @CustomerId IS NULL
    BEGIN
        INSERT INTO dbo.Customer (CustomerNo, FirstName, LastName, Email, Phone, CountryCode, Status)
        VALUES (@CustomerNo, @FirstName, @LastName, @Email, @Phone, @countryCode, 'ACTIVE');
        SET @CustomerId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.Customer
           SET FirstName = ISNULL(@FirstName, FirstName),
               LastName  = ISNULL(@LastName, LastName),
               Email     = ISNULL(@Email, Email),
               Phone     = ISNULL(@Phone, Phone),
               CountryCode = ISNULL(@countryCode, CountryCode),
               ModifiedUtc = SYSUTCDATETIME()
         WHERE CustomerId = @CustomerId;
    END
END
GO
