-- sp_CleanupHistoricalData: Data retention policy with tenant/server/database granularity
CREATE PROCEDURE [qsh].[sp_CleanupHistoricalData]
    @RetentionDays INT = 90,
    @TenantName NVARCHAR(128) = NULL,
    @ServerName NVARCHAR(128) = NULL,
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @cutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, CAST(GETUTC() AS DATE))
    DECLARE @recordsToDelete BIGINT = 0
    DECLARE @runtimeStatsCount BIGINT = 0
    DECLARE @waitStatsCount BIGINT = 0
    DECLARE @orphanedIntervalCount BIGINT = 0

    PRINT 'Query Store Historical - Data Cleanup Report'
    PRINT 'Retention Days: ' + CAST(@RetentionDays AS VARCHAR(10))
    PRINT 'Cutoff Date: ' + CAST(@cutoffDate AS VARCHAR(25))
    PRINT 'Tenant Filter: ' + ISNULL(@TenantName, 'ALL')
    PRINT 'Server Filter: ' + ISNULL(@ServerName, 'ALL')
    PRINT 'Dry Run: ' + CASE WHEN @DryRun = 1 THEN 'YES' ELSE 'NO' END
    PRINT ''

    -- Count records to delete
    SELECT @runtimeStatsCount = COUNT(*)
    FROM [qsh].[QueryStoreRuntimeStats] rs
    INNER JOIN [qsh].[RuntimeStatsInterval] rsi 
        ON rs.[RuntimeStatsIntervalId] = rsi.[RuntimeStatsIntervalId]
        AND rs.[TenantName] = rsi.[TenantName]
        AND rs.[ServerName] = rsi.[ServerName]
    WHERE rsi.[IntervalStartTime] < @cutoffDate
      AND (@TenantName IS NULL OR rs.[TenantName] = @TenantName)
      AND (@ServerName IS NULL OR rs.[ServerName] = @ServerName)

    SELECT @waitStatsCount = COUNT(*)
    FROM [qsh].[QueryStoreWaitStats] ws
    INNER JOIN [qsh].[RuntimeStatsInterval] rsi 
        ON ws.[RuntimeStatsIntervalId] = rsi.[RuntimeStatsIntervalId]
        AND ws.[TenantName] = rsi.[TenantName]
        AND ws.[ServerName] = rsi.[ServerName]
    WHERE rsi.[IntervalStartTime] < @cutoffDate
      AND (@TenantName IS NULL OR ws.[TenantName] = @TenantName)
      AND (@ServerName IS NULL OR ws.[ServerName] = @ServerName)

    SELECT @orphanedIntervalCount = COUNT(*)
    FROM [qsh].[RuntimeStatsInterval]
    WHERE [IntervalStartTime] < @cutoffDate
      AND (@TenantName IS NULL OR [TenantName] = @TenantName)
      AND (@ServerName IS NULL OR [ServerName] = @ServerName)

    SET @recordsToDelete = @runtimeStatsCount + @waitStatsCount + @orphanedIntervalCount

    PRINT 'Records to be deleted:'
    PRINT '  Runtime Statistics: ' + CAST(@runtimeStatsCount AS VARCHAR(15))
    PRINT '  Wait Statistics: ' + CAST(@waitStatsCount AS VARCHAR(15))
    PRINT '  Orphaned Intervals: ' + CAST(@orphanedIntervalCount AS VARCHAR(15))
    PRINT '  Total Records to Delete: ' + CAST(@recordsToDelete AS VARCHAR(15))
    PRINT ''

    IF @DryRun = 0
    BEGIN
        PRINT 'Starting cleanup...'
        PRINT ''

        BEGIN TRANSACTION

        -- Delete old runtime statistics
        DELETE FROM [qsh].[QueryStoreRuntimeStats]
        WHERE [RuntimeStatsIntervalId] IN (
            SELECT [RuntimeStatsIntervalId] FROM [qsh].[RuntimeStatsInterval]
            WHERE [IntervalStartTime] < @cutoffDate
              AND (@TenantName IS NULL OR [TenantName] = @TenantName)
              AND (@ServerName IS NULL OR [ServerName] = @ServerName)
        )
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' runtime statistics records'

        -- Delete old wait statistics
        DELETE FROM [qsh].[QueryStoreWaitStats]
        WHERE [RuntimeStatsIntervalId] IN (
            SELECT [RuntimeStatsIntervalId] FROM [qsh].[RuntimeStatsInterval]
            WHERE [IntervalStartTime] < @cutoffDate
              AND (@TenantName IS NULL OR [TenantName] = @TenantName)
              AND (@ServerName IS NULL OR [ServerName] = @ServerName)
        )
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' wait statistics records'

        -- Delete old intervals
        DELETE FROM [qsh].[RuntimeStatsInterval]
        WHERE [IntervalStartTime] < @cutoffDate
          AND (@TenantName IS NULL OR [TenantName] = @TenantName)
          AND (@ServerName IS NULL OR [ServerName] = @ServerName)
        PRINT 'Deleted ' + CAST(@@ROWCOUNT AS VARCHAR(15)) + ' interval records'

        -- Delete old plan regressions
        DELETE FROM [qsh].[PlanRegressions]
        WHERE [DetectionDate] < @cutoffDate
          AND (@TenantName IS NULL OR [TenantName] = @TenantName)
          AND (@ServerName IS NULL OR [ServerName] = @ServerName)
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
END
GO
