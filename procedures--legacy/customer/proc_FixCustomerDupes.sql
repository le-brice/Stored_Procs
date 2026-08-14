/* ============================================================
   dbo.proc_FixCustomerDupes
   !!! LEGACY. Run manually every few months. Nobody fully trusts
   it. Original author left in 2019. !!!

   Finds probable duplicate customers (same lower(email), or same
   last name + phone) and merges the NEWER record into the OLDER
   surviving one using dbo.usp_MergeCustomers. Skips anything that
   already has status MERGED/BLOCKED.

   @WhatIf = 1 (default) just prints the pairs it WOULD merge.
   Set @WhatIf = 0 to actually do it. Please take a backup first.

   Known sharp edges:
     - email match ignores '+' aliases (foo+x@bar == foo@bar? no, it
       treats them as different. maybe that's wrong.)
     - if three+ records collide it merges them pairwise in id order
       which can chain. usually fine. usually.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE dbo.proc_FixCustomerDupes
    @WhatIf BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'dbo.proc_FixCustomerDupes', @ProcLogId = @plog OUTPUT;

    -- candidate pairs: survivor = lowest CustomerId in the dup group
    IF OBJECT_ID('tempdb..#dupes') IS NOT NULL DROP TABLE #dupes;

    ;WITH grp AS (
        SELECT CustomerId,
               LOWER(LTRIM(RTRIM(Email))) AS k_email,
               LOWER(LTRIM(RTRIM(LastName))) + '|' + ISNULL(Phone,'') AS k_namephone
          FROM dbo.Customer
         WHERE Status = 'ACTIVE'
    ),
    email_groups AS (
        SELECT k_email AS k, MIN(CustomerId) AS survivor
          FROM grp WHERE k_email IS NOT NULL AND k_email <> ''
         GROUP BY k_email HAVING COUNT(*) > 1
    ),
    np_groups AS (
        SELECT k_namephone AS k, MIN(CustomerId) AS survivor
          FROM grp WHERE k_namephone IS NOT NULL AND k_namephone <> '|'
         GROUP BY k_namephone HAVING COUNT(*) > 1
    )
    SELECT DISTINCT g.CustomerId AS SourceId, eg.survivor AS TargetId
      INTO #dupes
      FROM grp g JOIN email_groups eg ON eg.k = g.k_email
     WHERE g.CustomerId <> eg.survivor
    UNION
    SELECT DISTINCT g.CustomerId, ng.survivor
      FROM grp g JOIN np_groups ng ON ng.k = g.k_namephone
     WHERE g.CustomerId <> ng.survivor;

    IF @WhatIf = 1
    BEGIN
        SELECT * FROM #dupes ORDER BY TargetId, SourceId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = 'WHATIF - no changes';
        RETURN 0;
    END

    DECLARE @src INT, @tgt INT, @cnt INT = 0;
    DECLARE dup_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT SourceId, TargetId FROM #dupes ORDER BY TargetId, SourceId;
    OPEN dup_cur;
    FETCH NEXT FROM dup_cur INTO @src, @tgt;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- the source might already have been merged in a prior iteration of
        -- a chain; skip if so. (this is the bit nobody trusts)
        IF EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerId = @src AND Status = 'ACTIVE')
        BEGIN
            BEGIN TRY
                EXEC dbo.usp_MergeCustomers @SourceCustomerId = @src, @TargetCustomerId = @tgt;
                SET @cnt = @cnt + 1;
            END TRY
            BEGIN CATCH
                EXEC util.usp_LogError @ProcName = 'dbo.proc_FixCustomerDupes';
                -- swallow + continue; one bad pair shouldn't stop the run
            END CATCH
        END
        FETCH NEXT FROM dup_cur INTO @src, @tgt;
    END
    CLOSE dup_cur; DEALLOCATE dup_cur;

    EXEC util.usp_LogEnd @ProcLogId = @plog, @RowsAffected = @cnt, @Message = 'merged dupes';
END
GO
