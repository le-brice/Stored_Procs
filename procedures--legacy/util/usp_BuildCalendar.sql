/* ============================================================
   util.usp_BuildCalendar
   (Re)populates ref.Calendar for a date range. Fiscal year here
   starts in February (don't ask -- finance decided in 2015).
   ============================================================ */
USE RetailDW;
GO
CREATE OR ALTER PROCEDURE util.usp_BuildCalendar
    @FromDate DATE = NULL,
    @ToDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate IS NULL SET @FromDate = '2015-01-01';
    IF @ToDate   IS NULL SET @ToDate   = DATEADD(YEAR, 2, CAST(SYSUTCDATETIME() AS DATE));

    ;WITH d AS (
        SELECT @FromDate AS dt
        UNION ALL
        SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < @ToDate
    )
    MERGE ref.Calendar AS tgt
    USING (
        SELECT
            dt,
            DATEPART(WEEKDAY, dt)                          AS dow,
            DATENAME(WEEKDAY, dt)                          AS dname,
            CASE WHEN DATEPART(WEEKDAY, dt) IN (1,7) THEN 1 ELSE 0 END AS isweekend,
            MONTH(dt)                                      AS mnum,
            DATENAME(MONTH, dt)                            AS mname,
            DATEPART(QUARTER, dt)                          AS qnum,
            YEAR(dt)                                       AS ynum,
            CASE WHEN MONTH(dt) >= 2 THEN YEAR(dt) ELSE YEAR(dt) - 1 END AS fy,
            ((MONTH(dt) + 10 - 1) % 12) + 1                AS fp
        FROM d
    ) AS src ON tgt.CalendarDate = src.dt
    WHEN MATCHED THEN UPDATE SET
        DayOfWeekNum = src.dow, DayName = src.dname, IsWeekend = src.isweekend,
        MonthNum = src.mnum, MonthName = src.mname, QuarterNum = src.qnum,
        YearNum = src.ynum, FiscalYear = src.fy, FiscalPeriod = src.fp
    WHEN NOT MATCHED THEN INSERT
        (CalendarDate, DayOfWeekNum, DayName, IsWeekend, MonthNum, MonthName,
         QuarterNum, YearNum, FiscalYear, FiscalPeriod, IsHoliday)
        VALUES
        (src.dt, src.dow, src.dname, src.isweekend, src.mnum, src.mname,
         src.qnum, src.ynum, src.fy, src.fp, 0)
    OPTION (MAXRECURSION 0);
END
GO
