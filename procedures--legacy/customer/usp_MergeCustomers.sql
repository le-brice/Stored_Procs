/* ============================================================
   dbo.usp_MergeCustomers
   Merges @SourceCustomerId INTO @TargetCustomerId. Re-points orders,
   addresses and loyalty to the target, sums loyalty points, marks
   the source MERGED with MergedIntoId set.

   Called by dbo.proc_FixCustomerDupes in a loop. Can also be run by
   hand by CS. There is NO undo. Be careful which way round you pass
   the ids (target survives).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MergeCustomers
    @SourceCustomerId INT,
    @TargetCustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'dbo.usp_MergeCustomers', @ProcLogId = @plog OUTPUT;

    BEGIN TRAN;
    BEGIN TRY
        IF @SourceCustomerId = @TargetCustomerId THROW 53001, 'Cannot merge a customer into itself', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerId = @TargetCustomerId AND Status = 'ACTIVE')
            THROW 53002, 'Target customer missing or not active', 1;

        -- move orders + addresses
        UPDATE sales.OrderHeader SET CustomerId = @TargetCustomerId WHERE CustomerId = @SourceCustomerId;
        UPDATE dbo.CustomerAddress SET CustomerId = @TargetCustomerId, IsDefault = 0 WHERE CustomerId = @SourceCustomerId;

        -- merge loyalty: ensure target has an account, then fold source points in
        DECLARE @tgtAcct INT, @srcAcct INT, @srcBal INT, @srcLife INT;
        EXEC dbo.usp_GetOrCreateLoyaltyAccount @CustomerId = @TargetCustomerId, @LoyaltyAccountId = @tgtAcct OUTPUT;
        SELECT @srcAcct = LoyaltyAccountId, @srcBal = PointsBalance, @srcLife = LifetimePoints
          FROM dbo.LoyaltyAccount WHERE CustomerId = @SourceCustomerId;

        IF @srcAcct IS NOT NULL
        BEGIN
            UPDATE dbo.LoyaltyTransaction SET LoyaltyAccountId = @tgtAcct WHERE LoyaltyAccountId = @srcAcct;
            UPDATE dbo.LoyaltyAccount
               SET PointsBalance = PointsBalance + ISNULL(@srcBal,0),
                   LifetimePoints = LifetimePoints + ISNULL(@srcLife,0)
             WHERE LoyaltyAccountId = @tgtAcct;
            -- orphan the source account (can't delete, FK from txns historically)
            UPDATE dbo.LoyaltyAccount SET PointsBalance = 0, LifetimePoints = 0 WHERE LoyaltyAccountId = @srcAcct;
        END

        UPDATE dbo.Customer
           SET Status = 'MERGED', MergedIntoId = @TargetCustomerId, ModifiedUtc = SYSUTCDATETIME()
         WHERE CustomerId = @SourceCustomerId;

        EXEC dbo.usp_RecalcLoyaltyTier @CustomerId = @TargetCustomerId;

        COMMIT;
        EXEC util.usp_LogEnd @ProcLogId = @plog,
             @Message = CONCAT('merged ', @SourceCustomerId, ' -> ', @TargetCustomerId);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC util.usp_LogError @ProcName = 'dbo.usp_MergeCustomers';
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
