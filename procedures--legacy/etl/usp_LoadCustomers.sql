/* ============================================================
   etl.usp_LoadCustomers
   Processes unprocessed rows in stg.RawCustomer into dbo.Customer
   via dbo.usp_UpsertCustomer (one call per row -- RBAR, but the
   volumes are small and nobody's rewritten it).

   Rows with no CustomerNo get a generated one (CUST-<rowid>).
   Marks rows IsProcessed = 1 as it goes.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_LoadCustomers
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_LoadCustomers', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        DECLARE @rowId BIGINT, @no VARCHAR(50), @fn VARCHAR(100), @ln VARCHAR(100),
                @em VARCHAR(200), @ph VARCHAR(60), @co VARCHAR(60), @cid INT, @cnt INT = 0;

        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT RowId, CustomerNo, FirstName, LastName, Email, Phone, Country
              FROM stg.RawCustomer WHERE IsProcessed = 0;
        OPEN c;
        FETCH NEXT FROM c INTO @rowId, @no, @fn, @ln, @em, @ph, @co;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @no IS NULL OR LTRIM(RTRIM(@no)) = '' SET @no = CONCAT('CUST-', @rowId);

            BEGIN TRY
                EXEC dbo.usp_UpsertCustomer
                     @CustomerNo = @no, @FirstName = @fn, @LastName = @ln,
                     @Email = @em, @Phone = @ph, @CountryRaw = @co, @CustomerId = @cid OUTPUT;
                SET @cnt = @cnt + 1;
                UPDATE stg.RawCustomer SET IsProcessed = 1 WHERE RowId = @rowId;
            END TRY
            BEGIN CATCH
                EXEC util.usp_LogError @ProcName = 'etl.usp_LoadCustomers', @BatchId = @BatchId;
                -- leave IsProcessed = 0 so it can be retried after fixing data
            END CATCH

            FETCH NEXT FROM c INTO @rowId, @no, @fn, @ln, @em, @ph, @co;
        END
        CLOSE c; DEALLOCATE c;

        EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @cnt;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','c') >= 0 BEGIN CLOSE c; DEALLOCATE c; END
        EXEC util.usp_LogError @ProcName = 'etl.usp_LoadCustomers', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
