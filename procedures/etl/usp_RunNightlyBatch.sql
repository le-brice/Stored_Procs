/* ============================================================
   etl.usp_RunNightlyBatch
   The conductor. Called by SQL Agent job JOB_NightlyBatch ~02:00.

   Opens a util.BatchControl row, builds a step list, then walks it
   in order, threading @BatchId through everything so a failure can
   be traced across procs via util.ProcLog / util.ErrorLog.

   ------------------------------------------------------------
   HOW IT WORKS NOW
   ------------------------------------------------------------
   Up to 2019 this proc was a flat list of EXEC statements. It grew
   a nested TRY per step, then a cursor for the per-warehouse
   reorder sweep, then a retry, and by 2021 the nesting was deep
   enough that nobody could tell which failures aborted the batch
   and which didn't.

   It is now table-driven. #steps holds one row per unit of work
   with its command, its dependency, whether a failure aborts the
   batch, and how many retries it gets. The driver loop reads that
   table and dispatches through sp_executesql.

   That means the command text is a string. Which means the
   parameters are a string. Which means if you add a step you must
   get the quoting right, and a typo is a runtime error at 02:00
   rather than a compile error now. This is the trade for being
   able to see the pipeline as data instead of as control flow.
   Run with @DryRun = 1 after touching the step list -- it prints
   every command without executing it.

   ------------------------------------------------------------
   ORDER AND DEPENDENCIES
   ------------------------------------------------------------
     10  FX rates       (flaky, may no-op -- see usp_LoadFxRates)
     20  customers
     30  products
     40  import orders  (hard dep on 20 + 30)
     50  sales journal
     60  returns journal
     70  settlement
     80  reconciliation (dep on 70)
     90  reports        (best effort)
    100  reorder sweep  (per warehouse, best effort)
    110  SLA + summary

   A step with DependsOn set is SKIPPED if its dependency did not
   succeed. A step with AbortOnFail = 1 stops the batch. Finance
   steps abort; reports and reorder do not.

   FX (step 10) has AbortOnFail = 0 AND never throws anyway,
   because etl.usp_LoadFxRates silently no-ops when the feed is
   late. So a missing FX feed does not stop the batch and does not
   even mark the step failed -- it just quietly makes every
   multi-currency number in the night's journal wrong. That is the
   whole problem and it is still not fixed. See FIN-118 / ETL-12.

   ------------------------------------------------------------
   CONTROLS
   ------------------------------------------------------------
   @BusinessDate    defaults to yesterday.
   @StartAtStep     resume a failed batch from a step number.
   @StopAfterStep   stop early (for testing).
   @SkipSteps       comma-separated step numbers to skip.
   @DryRun          print the commands, execute nothing.
   @Reprocess       passed down to the import as @ReprocessRejects.

   Resuming with @StartAtStep does NOT re-check dependencies for
   steps before the start point -- it assumes you know they ran.
   Resuming at 50 on a night when 40 never ran will happily post a
   journal for orders that were never imported.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_RunNightlyBatch
    @BusinessDate  DATE        = NULL,
    @StartAtStep   INT         = NULL,
    @StopAfterStep INT         = NULL,
    @SkipSteps     VARCHAR(200) = NULL,
    @Reprocess     BIT         = 0,
    @DryRun        BIT         = 0,
    @DebugLevel    TINYINT     = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @BusinessDate IS NULL
        SET @BusinessDate = DATEADD(DAY, -1, CAST(SYSUTCDATETIME() AS DATE));

    DECLARE @BatchId UNIQUEIDENTIFIER = NEWID();

    INSERT INTO util.BatchControl (BatchId, BatchName, BusinessDate, Status)
    VALUES (@BatchId, 'NightlyBatch', @BusinessDate, 'RUNNING');

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_RunNightlyBatch',
         @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    DECLARE @cfg          VARCHAR(400),
            @maxRetry     TINYINT,
            @retryDelaySec INT,
            @retryDelay   CHAR(8),
            @slaMinutes   INT,
            @batchStart   DATETIME2(3) = SYSUTCDATETIME(),
            @elapsedMin   INT = 0,
            @stepsRun     INT = 0,
            @stepsOk      INT = 0,
            @stepsFailed  INT = 0,
            @stepsSkipped INT = 0,
            @aborted      BIT = 0,
            @msg          VARCHAR(2000);

    BEGIN TRY

        /* ========================================================
           SECTION 1 -- config
           ======================================================== */

        EXEC util.usp_GetConfig @ParamKey = 'batch.step.retry.max',
             @Default = '2', @Value = @cfg OUTPUT;
        SET @maxRetry = ISNULL(TRY_CONVERT(TINYINT, @cfg), 2);

        EXEC util.usp_GetConfig @ParamKey = 'batch.step.retry.delay.seconds',
             @Default = '5', @Value = @cfg OUTPUT;
        SET @retryDelaySec = ISNULL(TRY_CONVERT(INT, @cfg), 5);

        /* WAITFOR wants 'hh:mm:ss'. Clamped at 5 minutes because
           somebody once set this to 3600 and the batch was still
           sleeping when the business came in. */
        IF @retryDelaySec > 300 SET @retryDelaySec = 300;
        IF @retryDelaySec < 0   SET @retryDelaySec = 0;
        SET @retryDelay = CONVERT(CHAR(8), DATEADD(SECOND, @retryDelaySec, CAST('00:00:00' AS TIME)), 108);

        EXEC util.usp_GetConfig @ParamKey = 'batch.sla.minutes',
             @Default = '90', @Value = @cfg OUTPUT;
        SET @slaMinutes = ISNULL(TRY_CONVERT(INT, @cfg), 90);

        IF @DebugLevel > 0
            PRINT CONCAT('[batch] ', CONVERT(VARCHAR(10), @BusinessDate),
                         ' id=', CONVERT(VARCHAR(36), @BatchId),
                         ' retry=', @maxRetry, '@', @retryDelay,
                         ' sla=', @slaMinutes, 'm',
                         ' dryRun=', @DryRun);

        /* ========================================================
           SECTION 2 -- the step list
           ------------------------------------------------------------
           Command text is built with the business date and batch id
           already substituted, because sp_executesql parameterised
           calls and per-step OUTPUT params turned out to be more
           trouble than string building. The values are a DATE and a
           UNIQUEIDENTIFIER, both formatted by CONVERT, so the
           injection surface is nil -- but do not extend this
           pattern to anything that takes user text.
           ======================================================== */

        DECLARE @dt  VARCHAR(10) = CONVERT(VARCHAR(10), @BusinessDate, 23);
        DECLARE @bid VARCHAR(36) = CONVERT(VARCHAR(36), @BatchId);

        IF OBJECT_ID('tempdb..#steps') IS NOT NULL DROP TABLE #steps;

        CREATE TABLE #steps (
            StepNo       INT          NOT NULL PRIMARY KEY,
            StepName     VARCHAR(60)  NOT NULL,
            Command      NVARCHAR(1000) NOT NULL,
            DependsOn    INT          NULL,
            AbortOnFail  BIT          NOT NULL DEFAULT 1,
            MaxRetry     TINYINT      NULL,     -- NULL -> config default
            ConfigGate   VARCHAR(100) NULL,     -- skip when this key is '0'
            Status       VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
            Attempts     TINYINT      NOT NULL DEFAULT 0,
            StartedUtc   DATETIME2(3) NULL,
            EndedUtc     DATETIME2(3) NULL,
            ElapsedMs    INT          NULL,
            ErrNumber    INT          NULL,
            ErrMessage   VARCHAR(1000) NULL
        );

        INSERT INTO #steps (StepNo, StepName, Command, DependsOn, AbortOnFail, MaxRetry, ConfigGate)
        VALUES
            /* --- reference --- */
            (10, 'load fx rates',
                 N'EXEC etl.usp_LoadFxRates @BatchId = ''' + @bid + N'''',
                 NULL, 0, 1, NULL),

            /* --- masters --- */
            (20, 'load customers',
                 N'EXEC etl.usp_LoadCustomers @BatchId = ''' + @bid + N'''',
                 NULL, 1, NULL, NULL),
            (30, 'load products',
                 N'EXEC etl.usp_LoadProducts @BatchId = ''' + @bid + N'''',
                 NULL, 1, NULL, NULL),

            /* --- orders. hard dependency on the masters. Depends on
                   30 only, because #steps has one DependsOn column
                   and 30 is the one that fails more often. If 20
                   fails and 30 succeeds this still runs and rejects
                   every order for a new customer. ETL-104. --- */
            (40, 'import raw orders',
                 N'EXEC etl.usp_ImportRawOrders @BatchId = ''' + @bid
                 + N''', @AutoConfirm = 1, @ReprocessRejects = '
                 + CONVERT(NVARCHAR(1), @Reprocess),
                 30, 1, NULL, NULL),

            /* --- finance. These MUST run together and abort. --- */
            (50, 'sales journal',
                 N'EXEC fin.usp_GenerateSalesJournal @BusinessDate = ''' + @dt
                 + N''', @BatchId = ''' + @bid + N'''',
                 40, 1, NULL, NULL),
            (60, 'returns journal',
                 N'EXEC fin.usp_GenerateReturnsJournal @BusinessDate = ''' + @dt
                 + N''', @BatchId = ''' + @bid + N'''',
                 40, 1, NULL, NULL),
            (70, 'build settlement',
                 N'EXEC fin.usp_BuildSettlement @SettlementDate = ''' + @dt
                 + N''', @BatchId = ''' + @bid + N'''',
                 NULL, 1, NULL, NULL),
            (80, 'reconcile settlements',
                 N'EXEC fin.usp_ReconcileSettlements @ReconDate = ''' + @dt
                 + N''', @BatchId = ''' + @bid + N'''',
                 70, 1, NULL, NULL),

            /* --- reporting. Best effort: a broken report can be
                   rebuilt by hand, and holding the batch open for it
                   delays the morning extracts. --- */
            (90, 'refresh reports',
                 N'EXEC rpt.usp_RefreshAllReports @BusinessDate = ''' + @dt
                 + N''', @BatchId = ''' + @bid + N'''',
                 NULL, 0, NULL, NULL),

            /* --- reorder sweep. Handled specially below: this row is
                   a placeholder, the driver expands it per active
                   warehouse. --- */
            (100, 'reorder sweep (per warehouse)',
                  N'-- expanded per warehouse by the driver',
                  NULL, 0, NULL, 'reorder.enabled');

        /* honour @SkipSteps. STRING_SPLIT is 2016+, which is our
           floor everywhere except the DR box -- and the DR box does
           not run the nightly batch, so this is fine. */
        IF @SkipSteps IS NOT NULL AND LTRIM(RTRIM(@SkipSteps)) <> ''
        BEGIN
            UPDATE s
               SET Status = 'SKIPPED'
              FROM #steps s
              JOIN (SELECT TRY_CONVERT(INT, LTRIM(RTRIM(value))) AS StepNo
                      FROM STRING_SPLIT(@SkipSteps, ',')) k
                ON k.StepNo = s.StepNo;

            IF @DebugLevel > 0 PRINT CONCAT('[batch] skipping steps: ', @SkipSteps);
        END

        IF @StartAtStep IS NOT NULL
            UPDATE #steps SET Status = 'SKIPPED'
             WHERE StepNo < @StartAtStep AND Status = 'PENDING';

        IF @StopAfterStep IS NOT NULL
            UPDATE #steps SET Status = 'SKIPPED'
             WHERE StepNo > @StopAfterStep AND Status = 'PENDING';

        /* ========================================================
           SECTION 3 -- the driver
           ======================================================== */

        DECLARE @stepNo      INT,
                @stepName    VARCHAR(60),
                @command     NVARCHAR(1000),
                @dependsOn   INT,
                @abortOnFail BIT,
                @stepRetry   TINYINT,
                @gate        VARCHAR(100),
                @attempt     TINYINT,
                @stepStart   DATETIME2(3),
                @errNum      INT,
                @errMsg      VARCHAR(1000),
                @depStatus   VARCHAR(20),
                @gateValue   VARCHAR(400);

        DECLARE step_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT StepNo, StepName, Command, DependsOn, AbortOnFail, MaxRetry, ConfigGate
              FROM #steps
             WHERE Status = 'PENDING'
             ORDER BY StepNo;

        OPEN step_cur;
        FETCH NEXT FROM step_cur INTO @stepNo, @stepName, @command,
                                      @dependsOn, @abortOnFail, @stepRetry, @gate;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @aborted = 1
            BEGIN
                UPDATE #steps SET Status = 'SKIPPED',
                       ErrMessage = 'batch aborted by an earlier step'
                 WHERE StepNo = @stepNo;
                SET @stepsSkipped = @stepsSkipped + 1;

                FETCH NEXT FROM step_cur INTO @stepNo, @stepName, @command,
                                              @dependsOn, @abortOnFail, @stepRetry, @gate;
                CONTINUE;
            END

            /* ---- dependency gate ---- */
            IF @dependsOn IS NOT NULL
            BEGIN
                SELECT @depStatus = Status FROM #steps WHERE StepNo = @dependsOn;

                IF ISNULL(@depStatus, 'PENDING') <> 'SUCCESS'
                BEGIN
                    UPDATE #steps
                       SET Status = 'SKIPPED',
                           ErrMessage = CONCAT('dependency step ', @dependsOn,
                                               ' status ', ISNULL(@depStatus, 'PENDING'))
                     WHERE StepNo = @stepNo;

                    SET @stepsSkipped = @stepsSkipped + 1;

                    INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                    VALUES (@BatchId, 'etl.usp_RunNightlyBatch', 0,
                            CONCAT('step ', @stepNo, ' (', @stepName,
                                   ') skipped -- dependency ', @dependsOn,
                                   ' did not succeed'));

                    FETCH NEXT FROM step_cur INTO @stepNo, @stepName, @command,
                                                  @dependsOn, @abortOnFail, @stepRetry, @gate;
                    CONTINUE;
                END
            END

            /* ---- config gate ---- */
            IF @gate IS NOT NULL
            BEGIN
                SET @gateValue = NULL;
                EXEC util.usp_GetConfig @ParamKey = @gate, @Default = '1', @Value = @gateValue OUTPUT;

                IF ISNULL(@gateValue, '1') = '0'
                BEGIN
                    UPDATE #steps SET Status = 'SKIPPED',
                           ErrMessage = CONCAT('disabled by config ', @gate)
                     WHERE StepNo = @stepNo;
                    SET @stepsSkipped = @stepsSkipped + 1;

                    FETCH NEXT FROM step_cur INTO @stepNo, @stepName, @command,
                                                  @dependsOn, @abortOnFail, @stepRetry, @gate;
                    CONTINUE;
                END
            END

            /* ---- step 100 is special: expand per warehouse ---- */
            IF @stepNo = 100
            BEGIN
                DECLARE @wh INT, @whCode VARCHAR(10), @whOk INT = 0, @whFail INT = 0;

                UPDATE #steps SET Status = 'RUNNING', StartedUtc = SYSUTCDATETIME()
                 WHERE StepNo = 100;

                DECLARE wh_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT WarehouseId, WarehouseCode
                      FROM inv.Warehouse
                     WHERE IsActive = 1
                     ORDER BY WarehouseId;
                OPEN wh_cur;
                FETCH NEXT FROM wh_cur INTO @wh, @whCode;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    BEGIN TRY
                        IF @DryRun = 1
                            PRINT CONCAT('[dryrun] EXEC inv.usp_RunReorder @WarehouseId = ',
                                         @wh, ', @WhatIf = 0');
                        ELSE
                            EXEC inv.usp_RunReorder @WarehouseId = @wh, @WhatIf = 0;

                        SET @whOk = @whOk + 1;
                    END TRY
                    BEGIN CATCH
                        SET @whFail = @whFail + 1;

                        EXEC util.usp_LogError
                             @ProcName = 'etl.usp_RunNightlyBatch(reorder)',
                             @BatchId  = @BatchId;

                        INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                        VALUES (@BatchId, 'etl.usp_RunNightlyBatch', 0,
                                CONCAT('reorder failed for warehouse ', @whCode,
                                       ' -- continuing with the rest'));
                    END CATCH

                    FETCH NEXT FROM wh_cur INTO @wh, @whCode;
                END
                CLOSE wh_cur; DEALLOCATE wh_cur;

                UPDATE #steps
                   SET Status     = CASE WHEN @whFail = 0 THEN 'SUCCESS' ELSE 'PARTIAL' END,
                       EndedUtc   = SYSUTCDATETIME(),
                       ElapsedMs  = DATEDIFF(MILLISECOND, StartedUtc, SYSUTCDATETIME()),
                       ErrMessage = CONCAT(@whOk, ' warehouse(s) ok, ', @whFail, ' failed')
                 WHERE StepNo = 100;

                SET @stepsRun = @stepsRun + 1;
                IF @whFail = 0 SET @stepsOk = @stepsOk + 1;

                FETCH NEXT FROM step_cur INTO @stepNo, @stepName, @command,
                                              @dependsOn, @abortOnFail, @stepRetry, @gate;
                CONTINUE;
            END

            /* ---- ordinary step: dispatch with retries ---- */
            SET @attempt   = 0;
            SET @stepRetry = ISNULL(@stepRetry, @maxRetry);

            WHILE @attempt <= @stepRetry
            BEGIN
                SET @attempt = @attempt + 1;
                SET @errNum  = NULL;
                SET @errMsg  = NULL;
                SET @stepStart = SYSUTCDATETIME();

                UPDATE #steps
                   SET Status = 'RUNNING', Attempts = @attempt, StartedUtc = @stepStart
                 WHERE StepNo = @stepNo;

                IF @DebugLevel > 0 OR @DryRun = 1
                    PRINT CONCAT(CASE WHEN @DryRun = 1 THEN '[dryrun] ' ELSE '[batch] ' END,
                                 'step ', @stepNo, ' ', @stepName,
                                 CASE WHEN @attempt > 1
                                      THEN CONCAT(' (attempt ', @attempt, ')') ELSE '' END,
                                 ' :: ', @command);

                IF @DryRun = 1
                BEGIN
                    UPDATE #steps SET Status = 'SUCCESS', EndedUtc = SYSUTCDATETIME(), ElapsedMs = 0
                     WHERE StepNo = @stepNo;
                    BREAK;
                END

                BEGIN TRY
                    EXEC sys.sp_executesql @command;

                    UPDATE #steps
                       SET Status    = 'SUCCESS',
                           EndedUtc  = SYSUTCDATETIME(),
                           ElapsedMs = DATEDIFF(MILLISECOND, @stepStart, SYSUTCDATETIME())
                     WHERE StepNo = @stepNo;

                    SET @stepsOk = @stepsOk + 1;
                    BREAK;
                END TRY
                BEGIN CATCH
                    SET @errNum = ERROR_NUMBER();
                    SET @errMsg = LEFT(ERROR_MESSAGE(), 1000);

                    /* a step that opened its own transaction and left
                       it open is a bug in that step, but we cannot
                       carry on with an open transaction either. */
                    IF XACT_STATE() <> 0 ROLLBACK;

                    EXEC util.usp_LogError
                         @ProcName = 'etl.usp_RunNightlyBatch',
                         @BatchId  = @BatchId;

                    /* retry only the transient classes. Everything
                       else is deterministic and will fail again. */
                    IF @errNum IN (1205, 1222, -2, 2, 53, 10054) AND @attempt <= @stepRetry
                    BEGIN
                        UPDATE #steps SET Status = 'RETRY', ErrNumber = @errNum, ErrMessage = @errMsg
                         WHERE StepNo = @stepNo;

                        IF @DebugLevel > 0
                            PRINT CONCAT('[batch] step ', @stepNo, ' transient err ', @errNum,
                                         ' -- retrying in ', @retryDelay);

                        IF @retryDelaySec > 0 WAITFOR DELAY @retryDelay;
                        CONTINUE;
                    END

                    UPDATE #steps
                       SET Status     = 'FAILED',
                           EndedUtc   = SYSUTCDATETIME(),
                           ElapsedMs  = DATEDIFF(MILLISECOND, @stepStart, SYSUTCDATETIME()),
                           ErrNumber  = @errNum,
                           ErrMessage = @errMsg
                     WHERE StepNo = @stepNo;

                    SET @stepsFailed = @stepsFailed + 1;

                    IF @abortOnFail = 1
                    BEGIN
                        SET @aborted = 1;

                        INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                        VALUES (@BatchId, 'etl.usp_RunNightlyBatch', @errNum,
                                CONCAT('ABORTING: step ', @stepNo, ' (', @stepName,
                                       ') failed after ', @attempt, ' attempt(s): ', @errMsg));
                    END
                    ELSE
                    BEGIN
                        INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
                        VALUES (@BatchId, 'etl.usp_RunNightlyBatch', @errNum,
                                CONCAT('step ', @stepNo, ' (', @stepName,
                                       ') failed but is best-effort -- continuing: ', @errMsg));
                    END

                    BREAK;
                END CATCH
            END  /* retry loop */

            SET @stepsRun = @stepsRun + 1;

            FETCH NEXT FROM step_cur INTO @stepNo, @stepName, @command,
                                          @dependsOn, @abortOnFail, @stepRetry, @gate;
        END
        CLOSE step_cur; DEALLOCATE step_cur;

        /* ========================================================
           SECTION 4 -- catch-up pass
           Best-effort steps that failed get exactly one more go,
           after everything else has finished and whatever was
           locking them has presumably let go. Only steps with
           AbortOnFail = 0, and only if the batch was not aborted.

           This is deliberately a second, simpler loop rather than
           folding back into the driver. Folding it in was tried in
           2022 and produced a batch that could loop forever if two
           best-effort steps failed each other's dependency.
           ======================================================== */

        IF @aborted = 0 AND EXISTS (SELECT 1 FROM #steps WHERE Status = 'FAILED' AND AbortOnFail = 0)
        BEGIN
            DECLARE @cuStep INT, @cuName VARCHAR(60), @cuCmd NVARCHAR(1000);

            DECLARE cu_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT StepNo, StepName, Command
                  FROM #steps
                 WHERE Status = 'FAILED' AND AbortOnFail = 0 AND StepNo <> 100
                 ORDER BY StepNo;
            OPEN cu_cur;
            FETCH NEXT FROM cu_cur INTO @cuStep, @cuName, @cuCmd;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @DebugLevel > 0
                    PRINT CONCAT('[batch] catch-up: step ', @cuStep, ' ', @cuName);

                BEGIN TRY
                    SET @stepStart = SYSUTCDATETIME();

                    EXEC sys.sp_executesql @cuCmd;

                    UPDATE #steps
                       SET Status     = 'SUCCESS',
                           EndedUtc   = SYSUTCDATETIME(),
                           ElapsedMs  = DATEDIFF(MILLISECOND, @stepStart, SYSUTCDATETIME()),
                           ErrMessage = CONCAT('recovered on the catch-up pass (was: ',
                                               ISNULL(ErrMessage, ''), ')')
                     WHERE StepNo = @cuStep;

                    SET @stepsFailed = @stepsFailed - 1;
                    SET @stepsOk     = @stepsOk + 1;
                END TRY
                BEGIN CATCH
                    IF XACT_STATE() <> 0 ROLLBACK;

                    EXEC util.usp_LogError
                         @ProcName = 'etl.usp_RunNightlyBatch(catchup)',
                         @BatchId  = @BatchId;

                    UPDATE #steps
                       SET ErrMessage = LEFT(CONCAT('failed twice: ', ERROR_MESSAGE()), 1000)
                     WHERE StepNo = @cuStep;
                END CATCH

                FETCH NEXT FROM cu_cur INTO @cuStep, @cuName, @cuCmd;
            END
            CLOSE cu_cur; DEALLOCATE cu_cur;
        END

        /* ========================================================
           SECTION 5 -- SLA check
           ======================================================== */

        SET @elapsedMin = DATEDIFF(MINUTE, @batchStart, SYSUTCDATETIME());

        IF @elapsedMin > @slaMinutes
        BEGIN
            /* the slowest step is nearly always 40 (import), because
               it is three nested cursors driving the OLTP procs.
               Naming it in the alert saves an investigation. */
            SELECT @msg = CONCAT('nightly batch took ', @elapsedMin,
                                 ' minutes against an SLA of ', @slaMinutes,
                                 '. Slowest step: ',
                                 ISNULL((SELECT TOP (1) CONCAT(StepNo, ' ', StepName, ' (',
                                                              ElapsedMs / 1000, 's)')
                                           FROM #steps
                                          WHERE ElapsedMs IS NOT NULL
                                          ORDER BY ElapsedMs DESC), '(unknown)'));

            INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
            VALUES (@BatchId, 'etl.usp_RunNightlyBatch', 0, @msg);
        END

        /* ========================================================
           SECTION 6 -- summary
           The step table is a temp table and dies with the session,
           so anything worth keeping has to be written out here.
           util.ProcLog.Message is VARCHAR(2000) which is not enough
           for a bad night, so the per-step detail goes to ErrorLog
           (ab)used as a run log and the summary goes to ProcLog.
           ======================================================== */

        INSERT INTO util.ErrorLog (BatchId, ProcName, ErrorNumber, ErrorMessage)
        SELECT @BatchId, 'etl.usp_RunNightlyBatch(steps)', 0,
               CONCAT('step ', StepNo, ' ', StepName,
                      ' -> ', Status,
                      CASE WHEN Attempts > 1 THEN CONCAT(' after ', Attempts, ' attempts') ELSE '' END,
                      CASE WHEN ElapsedMs IS NOT NULL
                           THEN CONCAT(' in ', ElapsedMs, 'ms') ELSE '' END,
                      CASE WHEN ErrMessage IS NOT NULL
                           THEN CONCAT(' -- ', LEFT(ErrMessage, 300)) ELSE '' END)
          FROM #steps
         ORDER BY StepNo;

        IF @DebugLevel > 0
            SELECT StepNo, StepName, Status, Attempts, ElapsedMs, ErrNumber, ErrMessage
              FROM #steps ORDER BY StepNo;

        SET @msg = CONCAT('batch ', CONVERT(VARCHAR(36), @BatchId),
                          ' date ', CONVERT(VARCHAR(10), @BusinessDate),
                          ': ', @stepsOk, ' ok, ',
                          @stepsFailed, ' failed, ',
                          @stepsSkipped, ' skipped, ',
                          @elapsedMin, ' min',
                          CASE WHEN @aborted = 1 THEN ' [ABORTED]' ELSE '' END);

        IF @aborted = 1
        BEGIN
            UPDATE util.BatchControl
               SET Status = 'FAILED', EndedUtc = SYSUTCDATETIME()
             WHERE BatchId = @BatchId;

            EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED',
                 @RowsAffected = @stepsRun, @Message = @msg;

            IF OBJECT_ID('tempdb..#steps') IS NOT NULL DROP TABLE #steps;

            /* rethrow so SQL Agent marks the job failed and the
               on-call alert fires. Without this the job history
               shows a green tick for a batch that posted nothing. */
            THROW 56001, 'Nightly batch aborted -- see util.ErrorLog for the failing step', 1;
        END

        /* a batch with best-effort failures is a SUCCESS with
           caveats. Finance only cares that 50-80 ran. */
        UPDATE util.BatchControl
           SET Status = CASE WHEN @stepsFailed > 0 THEN 'SUCCESS' ELSE 'SUCCESS' END,
               EndedUtc = SYSUTCDATETIME()
         WHERE BatchId = @BatchId;

        EXEC util.usp_LogEnd @ProcLogId = @plog,
             @RowsAffected = @stepsRun, @Message = @msg;

        IF OBJECT_ID('tempdb..#steps') IS NOT NULL DROP TABLE #steps;

        RETURN 0;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','step_cur') >= 0 BEGIN CLOSE step_cur; DEALLOCATE step_cur; END
        IF CURSOR_STATUS('local','wh_cur')   >= 0 BEGIN CLOSE wh_cur;   DEALLOCATE wh_cur;   END
        IF CURSOR_STATUS('local','cu_cur')   >= 0 BEGIN CLOSE cu_cur;   DEALLOCATE cu_cur;   END

        IF XACT_STATE() <> 0 ROLLBACK;

        UPDATE util.BatchControl
           SET Status = 'FAILED', EndedUtc = SYSUTCDATETIME()
         WHERE BatchId = @BatchId;

        EXEC util.usp_LogError @ProcName = 'etl.usp_RunNightlyBatch', @BatchId = @BatchId;
        EXEC util.usp_LogEnd   @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
