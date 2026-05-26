/*
================================================================================
Query Store Historical Data Warehouse - Maintenance Scripts
Purpose: Data retention, cleanup, and index maintenance
Author: GitHub Copilot
Date: 2026-05-26
================================================================================
*/

-- Set database context
-- USE [HistoricalQueryStore]
-- GO

-- ============================================================================
-- 1. DATA RETENTION POLICY
-- ============================================================================

IF OBJECT_ID('sp_CleanupHistoricalData', 'P') IS NOT NULL
    DROP PROCEDURE sp_CleanupHistoricalData
GO

CREATE PROCEDURE sp_CleanupHistoricalData
    @RetentionDays INT = 90,
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @cutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, CAST(GETUTC() AS DATE))
    DECLARE @recordsToDelete BIGINT = 0
    DECLARE @runtimeStatsCount BIGINT = 0
    DECLARE @waitStatsCount BIGINT = 0
    DECLARE @orphanedIntervalCount BIGINT = 0
    DECLARE @orphanedPlanCount BIGINT = 0

    PRINT '==============================================='
    PRINT 'Query Store Historical - Data Cleanup Report'
    PRINT '==============================================='
    PRINT 'Retention Days: ' + CAST(@RetentionDays AS VARCHAR(10))
    PRINT 'Cutoff Date: ' + CAST(@cutoffDate AS VARCHAR(25))
    PRINT 'Dry Run: ' + CASE WHEN @DryRun = 1 THEN 'YES' ELSE 'NO' END
    PRINT ''

    -- Count records to delete
    SELECT @runtimeStatsCount = COUNT(*)
    FROM qsh.QueryStoreRuntimeStats rs
    INNER JOIN qsh.RuntimeStatsInterval rsi 
        ON rs.RuntimeStatsIntervalId = rsi.RuntimeStatsIntervalId
    WHERE rsi.IntervalStartTime < @cutoffDate

    SELECT @waitStatsCount = COUNT(*)
    FROM qsh.QueryStoreWaitStats ws
    INNER JOIN qsh.RuntimeStatsInterval rsi 
        ON ws.RuntimeStatsIntervalId = rsi.RuntimeStatsIntervalId
    WHERE rsi.IntervalStartTime < @cutoffDate

    SELECT @orphanedIntervalCount = COUNT(*)
    FROM qsh.RuntimeStatsInterval
    WHERE IntervalStartTime < @cutoffDate

    SELECT @orphanedPlanCount = COUNT(DISTINCT p.PlanId)
    FROM qsh.QueryStorePlan p
    LEFT JOIN qsh.QueryStoreRuntimeStats rs ON p.PlanId = rs.PlanId
    WHERE rs.PlanId IS NULL

    SET @recordsToDelete = @runtimeStatsCount + @waitStatsCount + @orphanedIntervalCount

    PRINT 'Records to be deleted:'
    PRINT '  Runtime Statistics: ' + CAST(@runtimeStatsCount AS VARCHAR(15))
    PRINT '  Wait Statistics: ' + CAST(@waitStatsCount AS VARCHAR(15))
    PRINT '  Orphaned Intervals: ' + CAST(@orphanedIntervalCount AS VARCHAR(15))
    PRINT '  Orphaned Plans: ' + CAST(@orphanedPlanCount AS VARCHAR(15))
    PRINT '  Total Records to Delete: ' + CAST(@recordsToDelete AS VARCHAR(15))
    PRINT ''

    IF @DryRun = 0
    BEGIN
        PRINT 'Starting cleanup...'
        PRINT ''

        BEGIN TRANSACTION

        -- Delete old runtime statistics
        DELETE FROM qsh.QueryStoreRuntimeStats
        WHERE RuntimeStatsIntervalId IN (
            SELECT RuntimeStatsIntervalId FROM qsh.RuntimeStatsInterval
            WHERE IntervalStartTime < @cutoffDate
        )
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' runtime statistics records'

        -- Delete old wait statistics
        DELETE FROM qsh.QueryStoreWaitStats
        WHERE RuntimeStatsIntervalId IN (
            SELECT RuntimeStatsIntervalId FROM qsh.RuntimeStatsInterval
            WHERE IntervalStartTime < @cutoffDate
        )
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' wait statistics records'

        -- Delete old intervals
        DELETE FROM qsh.RuntimeStatsInterval
        WHERE IntervalStartTime < @cutoffDate
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' interval records'

        -- Delete orphaned plans (no recent runtime stats)
        DELETE FROM qsh.QueryStorePlan
        WHERE PlanId IN (
            SELECT DISTINCT PlanId
            FROM (
                SELECT p.PlanId, MAX(rs.LoadDate) AS LastUsed
                FROM qsh.QueryStorePlan p
                LEFT JOIN qsh.QueryStoreRuntimeStats rs ON p.PlanId = rs.PlanId
                GROUP BY p.PlanId
            ) orphans
            WHERE LastUsed < @cutoffDate
        )
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' orphaned plan records'

        -- Delete old plan regressions
        DELETE FROM qsh.PlanRegressions
        WHERE DetectionDate < @cutoffDate
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' plan regression records'

        COMMIT TRANSACTION
        PRINT ''
        PRINT 'Cleanup completed successfully'
    END
    ELSE
    BEGIN
        PRINT 'DRY RUN MODE - No records deleted'
        PRINT 'Run with @DryRun = 0 to execute cleanup'
    END

    PRINT '==============================================='

END
GO

-- ============================================================================
-- 2. INDEX MAINTENANCE
-- ============================================================================

IF OBJECT_ID('sp_MaintainIndexes', 'P') IS NOT NULL
    DROP PROCEDURE sp_MaintainIndexes
GO

CREATE PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold FLOAT = 10.0,
    @RebuildThreshold FLOAT = 30.0,
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tableName NVARCHAR(128)
    DECLARE @indexName NVARCHAR(128)
    DECLARE @fragmentation FLOAT
    DECLARE @pageCount BIGINT
    DECLARE @SQL NVARCHAR(MAX)

    PRINT '==============================================='
    PRINT 'Index Maintenance Report'
    PRINT '==============================================='
    PRINT 'Fragmentation Threshold (REORGANIZE): ' + CAST(@FragmentationThreshold AS VARCHAR(5)) + '%'
    PRINT 'Rebuild Threshold: ' + CAST(@RebuildThreshold AS VARCHAR(5)) + '%'
    PRINT ''

    CREATE TABLE #IndexFragmentation (
        TableName NVARCHAR(128),
        IndexName NVARCHAR(128),
        Fragmentation FLOAT,
        PageCount BIGINT,
        Action NVARCHAR(50)
    )

    INSERT INTO #IndexFragmentation
    SELECT 
        OBJECT_NAME(ips.object_id),
        i.name,
        ips.avg_fragmentation_in_percent,
        ips.page_count,
        CASE 
            WHEN ips.avg_fragmentation_in_percent < @FragmentationThreshold THEN 'NONE'
            WHEN ips.avg_fragmentation_in_percent <= @RebuildThreshold THEN 'REORGANIZE'
            ELSE 'REBUILD'
        END
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id 
        AND ips.index_id = i.index_id
    WHERE ips.page_count > 1000
      AND ips.avg_fragmentation_in_percent > @FragmentationThreshold
      AND OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1

    -- Display fragmentation report
    SELECT * FROM #IndexFragmentation ORDER BY Fragmentation DESC
    PRINT ''
    PRINT 'Total indexes requiring maintenance: ' + CAST((SELECT COUNT(*) FROM #IndexFragmentation WHERE Action <> 'NONE') AS VARCHAR(5))
    PRINT ''

    -- Execute maintenance operations
    DECLARE index_cursor CURSOR FOR
    SELECT TableName, IndexName, Action FROM #IndexFragmentation WHERE Action <> 'NONE'

    OPEN index_cursor
    FETCH NEXT FROM index_cursor INTO @tableName, @indexName, @SQL

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @SQL = 'REORGANIZE'
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@indexName) + ' ON qsh.' + QUOTENAME(@tableName) + ' REORGANIZE'
            PRINT 'Reorganizing: ' + @tableName + '.' + @indexName
            IF @DebugMode = 0
                EXEC sp_executesql @SQL
        END
        ELSE IF @SQL = 'REBUILD'
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@indexName) + ' ON qsh.' + QUOTENAME(@tableName) + ' REBUILD'
            PRINT 'Rebuilding: ' + @tableName + '.' + @indexName
            IF @DebugMode = 0
                EXEC sp_executesql @SQL
        END

        FETCH NEXT FROM index_cursor INTO @tableName, @indexName, @SQL
    END

    CLOSE index_cursor
    DEALLOCATE index_cursor

    DROP TABLE #IndexFragmentation

    PRINT ''
    PRINT 'Index maintenance completed'
    PRINT '==============================================='

END
GO

-- ============================================================================
-- 3. UPDATE STATISTICS
-- ============================================================================

IF OBJECT_ID('sp_UpdateStatistics', 'P') IS NOT NULL
    DROP PROCEDURE sp_UpdateStatistics
GO

CREATE PROCEDURE sp_UpdateStatistics
    @TableName NVARCHAR(128) = NULL,
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX)
    DECLARE @statName NVARCHAR(128)
    DECLARE @tblName NVARCHAR(128)

    PRINT '==============================================='
    PRINT 'Statistics Update Report'
    PRINT '==============================================='

    IF @TableName IS NULL
    BEGIN
        PRINT 'Updating statistics for all tables in qsh schema...'
        
        DECLARE stat_cursor CURSOR FOR
        SELECT s.name, OBJECT_NAME(s.object_id)
        FROM sys.stats s
        INNER JOIN sys.objects o ON s.object_id = o.object_id
        WHERE o.schema_id = SCHEMA_ID('qsh')
          AND o.type = 'U'

        OPEN stat_cursor
        FETCH NEXT FROM stat_cursor INTO @statName, @tblName

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = 'UPDATE STATISTICS qsh.' + QUOTENAME(@tblName) + ' ' + QUOTENAME(@statName)
            PRINT 'Updating: ' + @tblName + '.' + @statName
            IF @DebugMode = 0
                EXEC sp_executesql @SQL
            
            FETCH NEXT FROM stat_cursor INTO @statName, @tblName
        END

        CLOSE stat_cursor
        DEALLOCATE stat_cursor
    END
    ELSE
    BEGIN
        PRINT 'Updating statistics for table: qsh.' + @TableName
        SET @SQL = 'UPDATE STATISTICS qsh.' + QUOTENAME(@TableName)
        IF @DebugMode = 0
            EXEC sp_executesql @SQL
    END

    PRINT ''
    PRINT 'Statistics update completed'
    PRINT '==============================================='

END
GO

-- ============================================================================
-- 4. STORAGE ANALYSIS
-- ============================================================================

IF OBJECT_ID('sp_AnalyzeStorageUsage', 'P') IS NOT NULL
    DROP PROCEDURE sp_AnalyzeStorageUsage
GO

CREATE PROCEDURE sp_AnalyzeStorageUsage
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '==============================================='
    PRINT 'Storage Usage Analysis'
    PRINT '==============================================='
    PRINT ''

    SELECT 
        SCHEMA_NAME(t.schema_id) AS SchemaName,
        t.name AS TableName,
        (ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) * 8 / 1024.0 AS TableSizeMB,
        ps.row_count AS RowCount
    FROM sys.tables t
    INNER JOIN sys.dm_db_partition_stats ps ON t.object_id = ps.object_id
    WHERE SCHEMA_NAME(t.schema_id) = 'qsh'
      AND ps.index_id IN (0, 1)
    ORDER BY TableSizeMB DESC

    PRINT ''
    PRINT 'Total storage used by qsh schema:'
    SELECT 
        SUM((ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) * 8 / 1024.0) AS TotalSizeMB
    FROM sys.tables t
    INNER JOIN sys.dm_db_partition_stats ps ON t.object_id = ps.object_id
    WHERE SCHEMA_NAME(t.schema_id) = 'qsh'
      AND ps.index_id IN (0, 1)

    PRINT '==============================================='

END
GO

-- ============================================================================
-- 5. AGENT JOB SCHEDULES (SQL Agent)
-- ============================================================================

-- Example: Create SQL Agent job for daily maintenance
/*

-- Step 1: Create maintenance job
EXEC msdb.dbo.sp_add_job 
    @job_name = 'QueryStore_DailyMaintenance',
    @enabled = 1

-- Step 2: Add cleanup step
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'QueryStore_DailyMaintenance',
    @step_name = 'CleanupOldData',
    @command = 'EXEC [HistoricalQueryStore].qsh.sp_CleanupHistoricalData @RetentionDays=90, @DryRun=0',
    @database_name = 'HistoricalQueryStore'

-- Step 3: Add index maintenance step
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'QueryStore_DailyMaintenance',
    @step_name = 'MaintainIndexes',
    @command = 'EXEC [HistoricalQueryStore].qsh.sp_MaintainIndexes @DebugMode=0',
    @database_name = 'HistoricalQueryStore'

-- Step 4: Add statistics update step
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'QueryStore_DailyMaintenance',
    @step_name = 'UpdateStatistics',
    @command = 'EXEC [HistoricalQueryStore].qsh.sp_UpdateStatistics @DebugMode=0',
    @database_name = 'HistoricalQueryStore'

-- Step 5: Create schedule (daily at 2 AM)
EXEC msdb.dbo.sp_add_schedule 
    @schedule_name = 'Daily_2AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000

-- Step 6: Attach schedule to job
EXEC msdb.dbo.sp_attach_schedule 
    @job_name = 'QueryStore_DailyMaintenance',
    @schedule_name = 'Daily_2AM'

-- Step 7: Add job target server
EXEC msdb.dbo.sp_add_jobserver 
    @job_name = 'QueryStore_DailyMaintenance',
    @server_name = '(local)'

*/

PRINT 'Maintenance Procedures Created Successfully'
GO
