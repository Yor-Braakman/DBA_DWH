-- ================================================================================
-- Query Store Historical - DBA Quick Reference Guide
-- Common queries and commands for operational use
-- ================================================================================

-- ============================================================================
-- 1. MONITORING & STATUS CHECKS
-- ============================================================================

-- Check latest data load
SELECT TOP 10
    TenantName, ServerName, DatabaseName,
    LastExtractTime, ExtractDurationSeconds,
    RecordsInserted, ExtractStatus
FROM qsh.ETLControl
ORDER BY LastExtractTime DESC
GO

-- Verify data freshness (should have data from last 4 hours)
SELECT 
    TenantName, ServerName, DatabaseName,
    MAX(LoadDate) AS LastLoadTime,
    DATEDIFF(HOUR, MAX(LoadDate), GETUTC()) AS HoursSinceLoad,
    COUNT(*) AS RecordCount
FROM qsh.QueryStoreRuntimeStats
GROUP BY TenantName, ServerName, DatabaseName
ORDER BY LastLoadTime DESC
GO

-- Count records in each table
SELECT 
    'QueryStoreQuery' AS TableName, COUNT(*) AS RowCount FROM qsh.QueryStoreQuery
UNION ALL
SELECT 'QueryStoreQueryText', COUNT(*) FROM qsh.QueryStoreQueryText
UNION ALL
SELECT 'QueryStorePlan', COUNT(*) FROM qsh.QueryStorePlan
UNION ALL
SELECT 'QueryStoreRuntimeStats', COUNT(*) FROM qsh.QueryStoreRuntimeStats
UNION ALL
SELECT 'QueryStoreWaitStats', COUNT(*) FROM qsh.QueryStoreWaitStats
UNION ALL
SELECT 'RuntimeStatsInterval', COUNT(*) FROM qsh.RuntimeStatsInterval
UNION ALL
SELECT 'PlanRegressions', COUNT(*) FROM qsh.PlanRegressions
GO

-- ============================================================================
-- 2. PERFORMANCE ANALYSIS
-- ============================================================================

-- Top 20 Slowest Queries (Last 7 Days)
SELECT TOP 20
    q.TenantName,
    q.ServerName,
    q.DatabaseName,
    q.QueryId,
    SUBSTRING(qt.QueryTextContent, 1, 100) AS QueryPreview,
    AVG(rs.AvgDurationMs) AS AvgDurationMs,
    MAX(rs.MaxDurationMs) AS MaxDurationMs,
    SUM(rs.CountExecutions) AS TotalExecutions,
    AVG(rs.AvgCpuTimeMs) AS AvgCpuTimeMs,
    AVG(rs.AvgMemoryUsedMb) AS AvgMemoryMB
FROM qsh.FactRuntimeStats rs
INNER JOIN qsh.DimQuery q ON rs.QueryDimKey = q.QueryDimKey
LEFT JOIN qsh.QueryStoreQueryText qt ON q.QueryTextId = qt.QueryTextId
WHERE rs.LoadDate >= DATEADD(DAY, -7, CAST(GETUTC() AS DATE))
GROUP BY q.TenantName, q.ServerName, q.DatabaseName, q.QueryId, qt.QueryTextContent
ORDER BY AvgDurationMs DESC
GO

-- Highest CPU Consumers
SELECT TOP 20
    q.TenantName,
    q.ServerName,
    q.QueryId,
    SUBSTRING(qt.QueryTextContent, 1, 80) AS QueryPreview,
    SUM(rs.CountExecutions * rs.AvgCpuTimeMs) / 1000.0 / 60.0 / 60.0 AS TotalCpuHours,
    AVG(rs.AvgCpuTimeMs) AS AvgCpuTimeMs,
    SUM(rs.CountExecutions) AS ExecutionCount
FROM qsh.FactRuntimeStats rs
INNER JOIN qsh.DimQuery q ON rs.QueryDimKey = q.QueryDimKey
LEFT JOIN qsh.QueryStoreQueryText qt ON q.QueryTextId = qt.QueryTextId
GROUP BY q.TenantName, q.ServerName, q.QueryId, qt.QueryTextContent
HAVING SUM(rs.CountExecutions * rs.AvgCpuTimeMs) > 1000000  -- >1M ms
ORDER BY TotalCpuHours DESC
GO

-- Memory Hogs
SELECT TOP 20
    q.TenantName,
    q.ServerName,
    q.QueryId,
    SUBSTRING(qt.QueryTextContent, 1, 80) AS QueryPreview,
    AVG(rs.AvgMemoryUsedMb) AS AvgMemoryMB,
    MAX(rs.MaxMemoryUsedMb) AS MaxMemoryMB,
    SUM(rs.CountExecutions) AS ExecutionCount
FROM qsh.FactRuntimeStats rs
INNER JOIN qsh.DimQuery q ON rs.QueryDimKey = q.QueryDimKey
LEFT JOIN qsh.QueryStoreQueryText qt ON q.QueryTextId = qt.QueryTextId
GROUP BY q.TenantName, q.ServerName, q.QueryId, qt.QueryTextContent
HAVING AVG(rs.AvgMemoryUsedMb) > 100  -- > 100 MB average
ORDER BY AvgMemoryMB DESC
GO

-- ============================================================================
-- 3. REGRESSION DETECTION & ANALYSIS
-- ============================================================================

-- Recent Plan Regressions (Last 24 Hours)
SELECT TOP 50
    pr.TenantName,
    pr.ServerName,
    pr.DatabaseName,
    pr.QueryId,
    qt.QueryTextContent,
    pr.DetectionDate,
    pr.OldAvgDurationMs,
    pr.NewAvgDurationMs,
    pr.DurationChangePercentage,
    pr.IsInvestigated,
    pr.Notes
FROM qsh.PlanRegressions pr
LEFT JOIN qsh.QueryStoreQuery q ON pr.QueryId = q.QueryId 
    AND pr.TenantName = q.TenantName
LEFT JOIN qsh.QueryStoreQueryText qt ON q.QueryTextId = qt.QueryTextId
WHERE pr.DetectionDate >= DATEADD(HOUR, -24, GETUTC())
    AND pr.DurationChangePercentage > 25  -- >25% regression
ORDER BY pr.DetectionDate DESC
GO

-- Top Regressions by Duration Impact
SELECT TOP 20
    pr.TenantName,
    pr.ServerName,
    pr.QueryId,
    COUNT(*) AS RegressionCount,
    AVG(pr.DurationChangePercentage) AS AvgDurationChangePercentage,
    MAX(pr.NewAvgDurationMs) AS MaxNewDurationMs,
    pr.IsInvestigated
FROM qsh.PlanRegressions pr
WHERE pr.DetectionDate >= DATEADD(DAY, -30, GETUTC())
GROUP BY pr.TenantName, pr.ServerName, pr.QueryId, pr.IsInvestigated
HAVING AVG(pr.DurationChangePercentage) > 25
ORDER BY AvgDurationChangePercentage DESC
GO

-- Mark regression as investigated
UPDATE qsh.PlanRegressions
SET IsInvestigated = 1,
    Notes = 'Root cause identified - missing index'
WHERE RegressionId = [YOUR_REGRESSION_ID]
GO

-- ============================================================================
-- 4. WAIT TIME ANALYSIS
-- ============================================================================

-- Total Wait Time by Category (Last 7 Days)
SELECT 
    TenantName,
    ServerName,
    WaitCategoryGroup,
    SUM(TotalWaitTimeMinutes) AS TotalWaitMinutes,
    SUM(TotalWaitTimeMinutes) / 60.0 AS TotalWaitHours,
    SUM(CountWaits) AS TotalWaits,
    AVG(AvgWaitTimeMs) AS AvgWaitTimeMs
FROM qsh.FactWaitStats fws
WHERE LoadDate >= DATEADD(DAY, -7, CAST(GETUTC() AS DATE))
GROUP BY TenantName, ServerName, WaitCategoryGroup
ORDER BY TotalWaitMinutes DESC
GO

-- Queries with Most Wait Time
SELECT TOP 50
    q.TenantName,
    q.ServerName,
    q.QueryId,
    SUBSTRING(qt.QueryTextContent, 1, 80) AS QueryPreview,
    ws.WaitCategoryGroup,
    SUM(ws.TotalWaitTimeMinutes) AS TotalWaitMinutes,
    SUM(ws.CountWaits) AS WaitCount,
    AVG(ws.AvgWaitTimeMs) AS AvgWaitTimeMs
FROM qsh.FactWaitStats ws
INNER JOIN qsh.DimQuery q ON ws.QueryDimKey = q.QueryDimKey
LEFT JOIN qsh.QueryStoreQueryText qt ON q.QueryTextId = qt.QueryTextId
WHERE ws.LoadDate >= DATEADD(DAY, -7, CAST(GETUTC() AS DATE))
GROUP BY q.TenantName, q.ServerName, q.QueryId, qt.QueryTextContent, ws.WaitCategoryGroup
ORDER BY TotalWaitMinutes DESC
GO

-- Memory Pressure Check (RESOURCE_SEMAPHORE waits)
SELECT 
    TenantName,
    ServerName,
    SUM(TotalWaitTimeMinutes) AS MemoryWaitMinutes,
    SUM(TotalWaitTimeMinutes) / 60.0 AS MemoryWaitHours,
    COUNT(DISTINCT QueryId) AS AffectedQueries
FROM qsh.FactWaitStats
WHERE WaitCategoryGroup = 'Memory Pressure'
    AND LoadDate >= DATEADD(DAY, -1, CAST(GETUTC() AS DATE))
GROUP BY TenantName, ServerName
HAVING SUM(TotalWaitTimeMinutes) > 60  -- >1 hour
ORDER BY MemoryWaitHours DESC
GO

-- ============================================================================
-- 5. PLAN ANALYSIS
-- ============================================================================

-- Queries with Multiple Plans (Plan Instability)
SELECT TOP 50
    q.TenantName,
    q.ServerName,
    q.QueryId,
    SUBSTRING(qt.QueryTextContent, 1, 80) AS QueryPreview,
    COUNT(DISTINCT rs.PlanId) AS PlanCount,
    MIN(p.CreationTime) AS FirstPlanDate,
    MAX(p.CreationTime) AS LatestPlanDate,
    COUNT(DISTINCT rs.RuntimeStatsIntervalId) AS IntervalCount
FROM qsh.FactRuntimeStats rs
INNER JOIN qsh.DimQuery q ON rs.QueryDimKey = q.QueryDimKey
INNER JOIN qsh.QueryStorePlan p ON rs.PlanId = p.PlanId
LEFT JOIN qsh.QueryStoreQueryText qt ON q.QueryTextId = qt.QueryTextId
GROUP BY q.TenantName, q.ServerName, q.QueryId, qt.QueryTextContent
HAVING COUNT(DISTINCT rs.PlanId) > 2
ORDER BY PlanCount DESC
GO

-- Plan Performance Comparison for Specific Query
DECLARE @QueryId BIGINT = [YOUR_QUERY_ID]
DECLARE @TenantName NVARCHAR(128) = '[YOUR_TENANT]'
DECLARE @ServerName NVARCHAR(128) = '[YOUR_SERVER]'

SELECT 
    p.PlanId,
    p.CreationTime,
    p.LastExecutionTime,
    COUNT(rs.RuntimeStatsId) AS ExecutionIntervals,
    AVG(rs.AvgDurationMs) AS AvgDurationMs,
    MAX(rs.MaxDurationMs) AS MaxDurationMs,
    SUM(rs.CountExecutions) AS TotalExecutions,
    AVG(rs.AvgCpuTimeMs) AS AvgCpuTimeMs
FROM qsh.QueryStorePlan p
LEFT JOIN qsh.FactRuntimeStats rs ON p.PlanId = rs.PlanId
    AND p.TenantName = rs.TenantName
    AND p.ServerName = rs.ServerName
WHERE p.QueryId = @QueryId
    AND p.TenantName = @TenantName
    AND p.ServerName = @ServerName
GROUP BY p.PlanId, p.CreationTime, p.LastExecutionTime
ORDER BY CreationTime DESC
GO

-- ============================================================================
-- 6. MULTI-TENANT ANALYSIS
-- ============================================================================

-- Performance by Tenant
SELECT 
    TenantName,
    COUNT(DISTINCT ServerName) AS ServerCount,
    COUNT(DISTINCT DatabaseName) AS DatabaseCount,
    COUNT(DISTINCT QueryId) AS UniqueQueryCount,
    AVG(AvgDurationMs) AS AvgDurationMs,
    SUM(CountExecutions) AS TotalExecutions,
    SUM(CountExecutions * AvgCpuTimeMs) / 1000.0 / 60.0 / 60.0 AS TotalCpuHours,
    AVG(AvgMemoryUsedMb) AS AvgMemoryMB
FROM qsh.FactRuntimeStats
WHERE LoadDate >= DATEADD(DAY, -7, CAST(GETUTC() AS DATE))
GROUP BY TenantName
ORDER BY TotalCpuHours DESC
GO

-- Server Performance Comparison
SELECT 
    ServerName,
    COUNT(DISTINCT TenantName) AS TenantCount,
    COUNT(DISTINCT DatabaseName) AS DatabaseCount,
    COUNT(DISTINCT QueryId) AS UniqueQueryCount,
    AVG(AvgDurationMs) AS AvgDurationMs,
    SUM(CountExecutions) AS TotalExecutions,
    COUNT(DISTINCT CASE WHEN IsRegression = 1 THEN QueryId END) AS RegressionQueryCount
FROM qsh.FactRuntimeStats
WHERE LoadDate >= DATEADD(DAY, -7, CAST(GETUTC() AS DATE))
GROUP BY ServerName
ORDER BY TotalExecutions DESC
GO

-- ============================================================================
-- 7. MAINTENANCE OPERATIONS
-- ============================================================================

-- Run data cleanup (dry run)
EXEC qsh.sp_CleanupHistoricalData @RetentionDays = 90, @DryRun = 1
GO

-- Run data cleanup (for real)
EXEC qsh.sp_CleanupHistoricalData @RetentionDays = 90, @DryRun = 0
GO

-- Check index fragmentation
EXEC qsh.sp_MaintainIndexes @FragmentationThreshold = 10.0, @DebugMode = 1
GO

-- Perform index maintenance
EXEC qsh.sp_MaintainIndexes @FragmentationThreshold = 10.0, @DebugMode = 0
GO

-- Update statistics
EXEC qsh.sp_UpdateStatistics
GO

-- Analyze storage usage
EXEC qsh.sp_AnalyzeStorageUsage
GO

-- ============================================================================
-- 8. DATA QUALITY CHECKS
-- ============================================================================

-- Check for orphaned records
SELECT 'Orphaned Runtime Stats' AS IssueType, COUNT(*) AS Count
FROM qsh.FactRuntimeStats rs
WHERE NOT EXISTS (SELECT 1 FROM qsh.DimQuery dq WHERE dq.QueryDimKey = rs.QueryDimKey)

UNION ALL

SELECT 'Orphaned Wait Stats', COUNT(*)
FROM qsh.FactWaitStats ws
WHERE NOT EXISTS (SELECT 1 FROM qsh.DimQuery dq WHERE dq.QueryDimKey = ws.QueryDimKey)

UNION ALL

SELECT 'Missing Query Text', COUNT(*)
FROM qsh.DimQuery dq
WHERE NOT EXISTS (SELECT 1 FROM qsh.QueryStoreQueryText qt WHERE qt.QueryTextId = dq.QueryTextId)
GO

-- Find NULL values in critical columns
SELECT 
    'DimQuery' AS TableName,
    'QueryTextId' AS ColumnName,
    COUNT(*) AS NullCount
FROM qsh.DimQuery
WHERE QueryTextId IS NULL
GO

-- ============================================================================
-- 9. EXPORT & REPORTING
-- ============================================================================

-- Export Top Queries to Excel-friendly format
SELECT 
    TenantName,
    ServerName,
    DatabaseName,
    QueryId,
    QueryText,
    CAST(AvgDurationMs AS DECIMAL(10,2)) AS AvgDurationMs,
    CAST(MaxDurationMs AS DECIMAL(10,2)) AS MaxDurationMs,
    TotalExecutions,
    CAST(AvgCpuTimeMs AS DECIMAL(10,2)) AS AvgCpuTimeMs,
    CAST(AvgMemoryUsedMb AS DECIMAL(10,2)) AS AvgMemoryMB
FROM qsh.FactTopQueries
ORDER BY AvgDurationMs DESC
GO

-- Generate regression report
SELECT 
    CAST(pr.DetectionDate AS DATE) AS Date,
    pr.TenantName,
    pr.ServerName,
    pr.DatabaseName,
    pr.QueryId,
    CAST(pr.OldAvgDurationMs AS DECIMAL(10,2)) AS OldDurationMs,
    CAST(pr.NewAvgDurationMs AS DECIMAL(10,2)) AS NewDurationMs,
    CAST(pr.DurationChangePercentage AS DECIMAL(10,2)) AS PercentChange,
    CASE WHEN pr.IsInvestigated = 1 THEN 'Yes' ELSE 'No' END AS Investigated
FROM qsh.PlanRegressions pr
WHERE CAST(pr.DetectionDate AS DATE) >= DATEADD(DAY, -30, CAST(GETUTC() AS DATE))
ORDER BY pr.DetectionDate DESC
GO

-- ============================================================================
-- 10. DIAGNOSTIC QUERIES
-- ============================================================================

-- ETL Health Check
SELECT 
    TenantName,
    ServerName,
    DatabaseName,
    COUNT(*) AS LoadCount,
    MAX(LastExtractTime) AS LatestLoad,
    CASE 
        WHEN MAX(LastExtractTime) >= DATEADD(HOUR, -4, GETUTC()) THEN 'HEALTHY'
        WHEN MAX(LastExtractTime) >= DATEADD(HOUR, -24, GETUTC()) THEN 'WARNING'
        ELSE 'CRITICAL'
    END AS Status
FROM qsh.ETLControl
GROUP BY TenantName, ServerName, DatabaseName
ORDER BY LatestLoad DESC
GO

-- Find slow ETL runs
SELECT TOP 20
    LastExtractTime,
    TenantName,
    ServerName,
    DatabaseName,
    ExtractDurationSeconds,
    RecordsInserted,
    ExtractStatus,
    CASE 
        WHEN ExtractDurationSeconds > 600 THEN 'SLOW'
        WHEN ExtractStatus = 'FAILED' THEN 'FAILED'
        ELSE 'OK'
    END AS Health
FROM qsh.ETLControl
ORDER BY LastExtractTime DESC
GO

-- Data freshness report
SELECT 
    TenantName,
    ServerName,
    DatabaseName,
    MAX(LoadDate) AS LastLoadTime,
    DATEDIFF(MINUTE, MAX(LoadDate), GETUTC()) AS MinutesSinceLoad,
    COUNT(*) AS RecordCount,
    COUNT(DISTINCT RuntimeStatsIntervalId) AS IntervalCount,
    DATEDIFF(DAY, MIN(LoadDate), MAX(LoadDate)) AS DataAgeInDays
FROM qsh.QueryStoreRuntimeStats
GROUP BY TenantName, ServerName, DatabaseName
ORDER BY LastLoadTime DESC
GO
