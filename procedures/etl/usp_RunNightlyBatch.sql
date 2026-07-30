/* ============================================================
   etl.usp_RunNightlyBatch
   The conductor. Called by SQL Agent job JOB_NightlyBatch ~02:00.
   Opens a util.BatchControl row, then runs the whole pipeline in
   order, threading @BatchId through everything so a failure can be
   traced across procs via util.ProcLog / util.ErrorLog.

   Order (DO NOT reshuffle without understanding the deps):
     1. ref data:   FX rates  (flaky, may no-op -- see usp_LoadFxRates)
     2. masters:    customers, products
     3. orders:     import raw orders (uses masters + fx + promos)
     4. finance:    sales journal, returns journal, settlement, recon
     5. reporting:  refresh all reports (uses fx again for LTV)

   @BusinessDate defaults to yesterday (we process the prior day).
   If any STEP throws, the batch is marked FAILED and we stop --
   EXCEPT FX load, whose silent no-op never throws (that's the
   whole problem). Finance + reporting steps are wrapped so one
   failing report doesn't block the others, but order/journal
   failures abort.
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE etl.usp_RunNightlyBatch
    @BusinessDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @BusinessDate IS NULL SET @BusinessDate = DATEADD(DAY, -1, CAST(SYSUTCDATETIME() AS DATE));

    DECLARE @BatchId UNIQUEIDENTIFIER = NEWID();
    INSERT INTO util.BatchControl (BatchId, BatchName, BusinessDate, Status)
    VALUES (@BatchId, 'NightlyBatch', @BusinessDate, 'RUNNING');

    DECLARE @plog BIGINT;
    EXEC util.usp_LogStart @ProcName = 'etl.usp_RunNightlyBatch', @BatchId = @BatchId, @ProcLogId = @plog OUTPUT;

    BEGIN TRY
        -- 1. reference
        EXEC etl.usp_LoadFxRates    @BatchId = @BatchId;

        -- 2. masters
        EXEC etl.usp_LoadCustomers  @BatchId = @BatchId;
        EXEC etl.usp_LoadProducts   @BatchId = @BatchId;

        -- 3. orders (hard dependency on masters above)
        EXEC etl.usp_ImportRawOrders @BatchId = @BatchId, @AutoConfirm = 1;

        -- 4. finance -- these MUST run together and abort on failure
        EXEC fin.usp_GenerateSalesJournal   @BusinessDate = @BusinessDate, @BatchId = @BatchId;
        EXEC fin.usp_GenerateReturnsJournal @BusinessDate = @BusinessDate, @BatchId = @BatchId;
        EXEC fin.usp_BuildSettlement        @SettlementDate = @BusinessDate, @BatchId = @BatchId;
        EXEC fin.usp_ReconcileSettlements   @ReconDate = @BusinessDate, @BatchId = @BatchId;

        -- 5. reporting -- best effort; log + continue if one fails
        BEGIN TRY
            EXEC rpt.usp_RefreshAllReports @BusinessDate = @BusinessDate, @BatchId = @BatchId;
        END TRY
        BEGIN CATCH
            EXEC util.usp_LogError @ProcName = 'etl.usp_RunNightlyBatch(reports)', @BatchId = @BatchId;
            -- swallow: reports can be rebuilt by hand, don't fail the whole batch
        END CATCH

        -- 6. reorder sweep per active warehouse
        DECLARE @wh INT;
        DECLARE wh_cur CURSOR LOCAL FAST_FORWARD FOR SELECT WarehouseId FROM inv.Warehouse WHERE IsActive = 1;
        OPEN wh_cur;
        FETCH NEXT FROM wh_cur INTO @wh;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                EXEC inv.usp_RunReorder @WarehouseId = @wh, @WhatIf = 0;
            END TRY
            BEGIN CATCH
                EXEC util.usp_LogError @ProcName = 'etl.usp_RunNightlyBatch(reorder)', @BatchId = @BatchId;
            END CATCH
            FETCH NEXT FROM wh_cur INTO @wh;
        END
        CLOSE wh_cur; DEALLOCATE wh_cur;

        UPDATE util.BatchControl SET Status = 'SUCCESS', EndedUtc = SYSUTCDATETIME() WHERE BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Message = CONCAT('batch ', CONVERT(VARCHAR(36), @BatchId));
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','wh_cur') >= 0 BEGIN CLOSE wh_cur; DEALLOCATE wh_cur; END
        UPDATE util.BatchControl SET Status = 'FAILED', EndedUtc = SYSUTCDATETIME() WHERE BatchId = @BatchId;
        EXEC util.usp_LogError @ProcName = 'etl.usp_RunNightlyBatch', @BatchId = @BatchId;
        EXEC util.usp_LogEnd @ProcLogId = @plog, @Status = 'FAILED';
        THROW;
    END CATCH
END
GO
