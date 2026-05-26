/*
================================================================================
Query Store Historical - Data Modeling Views
Purpose: Semantic layer views for Power BI and analysis
Includes: Dimension views and Fact views with proper aggregations
Author: GitHub Copilot
Date: 2026-05-26
================================================================================
*/

-- Set database context
-- USE [HistoricalQueryStore]
-- GO

-- ============================================================================
-- DIMENSION VIEWS
-- ============================================================================

-- 1. DimQuery - Query details with text
IF OBJECT_ID('qsh.DimQuery', 'V') IS NOT NULL
    DROP VIEW qsh.DimQuery
GO

CREATE VIEW qsh.DimQuery AS
SELECT 
    CONCAT(q.TenantName, '_', q.ServerName, '_', q.DatabaseName, '_', q.QueryId) AS QueryDimKey,
    q.QueryId,
    q.TenantName,
    q.ServerName,
    q.DatabaseName,
    q.ObjectId,
    qt.QueryTextContent AS QueryText,
    qt.StatementType,
    qt.QueryHash,
    qt.QueryPlanHash,
    CASE 
        WHEN q.ObjectId > 0 THEN 'Stored Procedure'
        WHEN q.ObjectId = 0 THEN 'Ad-hoc Query'
        ELSE 'Unknown'
    END AS QueryType,
    q.CompilationCount,
    q.AvgCompileCpuTimeMs,
    q.MaxCompileCpuTimeMs,
    q.AvgCompileMemoryMb,
    q.MaxCompileMemoryMb,
    q.CompilationStartTime,
    q.LoadDate
FROM qsh.QueryStoreQuery q
LEFT JOIN qsh.QueryStoreQueryText qt 
    ON q.QueryTextId = qt.QueryTextId 
    AND q.TenantName = qt.TenantName 
    AND q.ServerName = qt.ServerName
    AND q.DatabaseName = qt.DatabaseName
GO

-- 2. DimPlan - Execution plan details
IF OBJECT_ID('qsh.DimPlan', 'V') IS NOT NULL
    DROP VIEW qsh.DimPlan
GO

CREATE VIEW qsh.DimPlan AS
SELECT 
    CONCAT(p.TenantName, '_', p.ServerName, '_', p.DatabaseName, '_', p.PlanId) AS PlanDimKey,
    p.PlanId,
    p.TenantName,
    p.ServerName,
    p.DatabaseName,
    p.QueryId,
    p.EngineVersion,
    p.CompatibilityLevel,
    p.QueryHash,
    p.QueryPlanHash,
    p.PlanHandle,
    p.CreationTime,
    p.LastExecutionTime,
    DATEDIFF(DAY, p.CreationTime, p.LastExecutionTime) AS PlanAgeInDays,
    p.IsOnlineIndexPlan,
    p.IsParallelizable,
    CASE 
        WHEN p.QueryPlanCompressed IS NOT NULL THEN 'Compressed'
        WHEN p.QueryPlanText IS NOT NULL THEN 'XML'
        ELSE 'Unknown'
    END AS PlanStorage,
    p.LoadDate
FROM qsh.QueryStorePlan p
GO

-- 3. DimInterval - Time intervals for aggregation
IF OBJECT_ID('qsh.DimInterval', 'V') IS NOT NULL
    DROP VIEW qsh.DimInterval
GO

CREATE VIEW qsh.DimInterval AS
SELECT 
    RuntimeStatsIntervalId,
    TenantName,
    ServerName,
    IntervalStartTime,
    IntervalEndTime,
    IntervalDurationMinutes,
    CAST(IntervalStartTime AS DATE) AS IntervalDate,
    DATENAME(HOUR, IntervalStartTime) + ':' + 
        RIGHT('00' + DATENAME(MINUTE, IntervalStartTime), 2) AS IntervalTimeOfDay,
    DATENAME(WEEKDAY, IntervalStartTime) AS IntervalDayOfWeek,
    LoadDate
FROM qsh.RuntimeStatsInterval
GO

-- 4. DimWaitCategory - Wait categories reference
IF OBJECT_ID('qsh.DimWaitCategory', 'V') IS NOT NULL
    DROP VIEW qsh.DimWaitCategory
GO

CREATE VIEW qsh.DimWaitCategory AS
SELECT DISTINCT
    WaitCategoryId,
    WaitCategory,
    CASE 
        WHEN WaitCategory LIKE '%CPU%' THEN 'CPU Contention'
        WHEN WaitCategory LIKE '%MEMORY%' OR WaitCategory LIKE '%RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN WaitCategory LIKE '%IO%' OR WaitCategory LIKE '%PAGEIO%' THEN 'IO Contention'
        WHEN WaitCategory LIKE '%LOCK%' THEN 'Lock Contention'
        WHEN WaitCategory LIKE '%LATCH%' THEN 'Latch Contention'
        WHEN WaitCategory LIKE '%NETWORK%' THEN 'Network'
        ELSE 'Other'
    END AS WaitCategoryGroup
FROM qsh.QueryStoreWaitStats
GO

-- ============================================================================
-- FACT VIEWS WITH AGGREGATIONS
-- ============================================================================

-- 5. FactRuntimeStats - Performance metrics per query/plan/interval
IF OBJECT_ID('qsh.FactRuntimeStats', 'V') IS NOT NULL
    DROP VIEW qsh.FactRuntimeStats
GO

CREATE VIEW qsh.FactRuntimeStats AS
SELECT 
    rs.RuntimeStatsId,
    CONCAT(rs.TenantName, '_', rs.ServerName, '_', rs.DatabaseName, '_', rs.QueryId) AS QueryDimKey,
    CONCAT(rs.TenantName, '_', rs.ServerName, '_', rs.DatabaseName, '_', rs.PlanId) AS PlanDimKey,
    rs.RuntimeStatsIntervalId,
    rs.TenantName,
    rs.ServerName,
    rs.DatabaseName,
    rs.QueryId,
    rs.PlanId,
    rs.ExecutionType,
    rs.ExecutionTypeDesc,
    rs.CountExecutions,
    rs.AvgDurationMs,
    rs.AvgDurationMs / 1000.0 AS AvgDurationSeconds,
    rs.MaxDurationMs,
    rs.MinDurationMs,
    CASE 
        WHEN rs.StdevDurationMs IS NULL THEN 0
        ELSE rs.StdevDurationMs
    END AS StdevDurationMs,
    rs.AvgLogicalIoReads,
    rs.MaxLogicalIoReads,
    rs.AvgLogicalIoWrites,
    rs.MaxLogicalIoWrites,
    rs.AvgPhysicalIoReads,
    rs.MaxPhysicalIoReads,
    rs.AvgCpuTimeMs,
    rs.AvgCpuTimeMs / 1000.0 AS AvgCpuTimeSeconds,
    rs.MaxCpuTimeMs,
    rs.AvgClrTimeMs,
    rs.MaxClrTimeMs,
    rs.AvgElapsedTimeMs,
    rs.MaxElapsedTimeMs,
    rs.AvgMemoryUsedMb,
    rs.MaxMemoryUsedMb,
    rs.AvgRowCount,
    rs.MaxRowCount,
    rs.MinRowCount,
    (rs.AvgCpuTimeMs / NULLIF(rs.AvgDurationMs, 0)) * 100.0 AS CpuPercentageOfDuration,
    rs.IsRegression,
    CASE 
        WHEN rs.IsRegression = 1 THEN 'Regression Detected'
        ELSE 'Normal'
    END AS PerformanceStatus,
    rs.LoadDate
FROM qsh.QueryStoreRuntimeStats rs
GO

-- 6. FactWaitStats - Wait statistics by category
IF OBJECT_ID('qsh.FactWaitStats', 'V') IS NOT NULL
    DROP VIEW qsh.FactWaitStats
GO

CREATE VIEW qsh.FactWaitStats AS
SELECT 
    ws.WaitStatsId,
    CONCAT(ws.TenantName, '_', ws.ServerName, '_', ws.DatabaseName, '_', ws.QueryId) AS QueryDimKey,
    ws.RuntimeStatsIntervalId,
    ws.TenantName,
    ws.ServerName,
    ws.DatabaseName,
    ws.QueryId,
    ws.PlanId,
    ws.WaitCategory,
    ws.WaitCategoryId,
    CASE 
        WHEN ws.WaitCategory LIKE '%CPU%' THEN 'CPU Contention'
        WHEN ws.WaitCategory LIKE '%MEMORY%' OR ws.WaitCategory LIKE '%RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN ws.WaitCategory LIKE '%IO%' OR ws.WaitCategory LIKE '%PAGEIO%' THEN 'IO Contention'
        WHEN ws.WaitCategory LIKE '%LOCK%' THEN 'Lock Contention'
        WHEN ws.WaitCategory LIKE '%LATCH%' THEN 'Latch Contention'
        WHEN ws.WaitCategory LIKE '%NETWORK%' THEN 'Network'
        ELSE 'Other'
    END AS WaitCategoryGroup,
    ws.TotalWaitTimeMs,
    ws.TotalWaitTimeMs / 1000.0 / 60.0 AS TotalWaitTimeMinutes,
    ws.AvgWaitTimeMs,
    ws.MaxWaitTimeMs,
    ws.CountWaits,
    ws.QueryWaitTimeCategory,
    ws.LoadDate
FROM qsh.QueryStoreWaitStats ws
GO

-- 7. FactTopQueries - Pre-aggregated top queries (for dashboard performance)
IF OBJECT_ID('qsh.FactTopQueries', 'V') IS NOT NULL
    DROP VIEW qsh.FactTopQueries
GO

CREATE VIEW qsh.FactTopQueries AS
SELECT TOP 1000
    rs.TenantName,
    rs.ServerName,
    rs.DatabaseName,
    rs.QueryId,
    dq.QueryText,
    SUM(rs.CountExecutions) AS TotalExecutions,
    AVG(rs.AvgDurationMs) AS AvgDurationMs,
    MAX(rs.MaxDurationMs) AS MaxDurationMs,
    SUM(rs.CountExecutions * rs.AvgDurationMs) / 1000.0 AS TotalDurationSeconds,
    AVG(rs.AvgCpuTimeMs) AS AvgCpuTimeMs,
    SUM(rs.AvgLogicalIoReads) AS AvgLogicalIoReads,
    AVG(rs.AvgMemoryUsedMb) AS AvgMemoryUsedMb,
    COUNT(DISTINCT rs.RuntimeStatsIntervalId) AS IntervalsObserved
FROM qsh.QueryStoreRuntimeStats rs
LEFT JOIN qsh.DimQuery dq 
    ON rs.QueryId = dq.QueryId 
    AND rs.TenantName = dq.TenantName 
    AND rs.ServerName = dq.ServerName
    AND rs.DatabaseName = dq.DatabaseName
GROUP BY 
    rs.TenantName,
    rs.ServerName,
    rs.DatabaseName,
    rs.QueryId,
    dq.QueryText
ORDER BY TotalDurationSeconds DESC
GO

-- 8. FactWaitSummary - Aggregated wait statistics by category
IF OBJECT_ID('qsh.FactWaitSummary', 'V') IS NOT NULL
    DROP VIEW qsh.FactWaitSummary
GO

CREATE VIEW qsh.FactWaitSummary AS
SELECT 
    ws.TenantName,
    ws.ServerName,
    ws.DatabaseName,
    ws.WaitCategory,
    CASE 
        WHEN ws.WaitCategory LIKE '%CPU%' THEN 'CPU Contention'
        WHEN ws.WaitCategory LIKE '%MEMORY%' OR ws.WaitCategory LIKE '%RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN ws.WaitCategory LIKE '%IO%' OR ws.WaitCategory LIKE '%PAGEIO%' THEN 'IO Contention'
        WHEN ws.WaitCategory LIKE '%LOCK%' THEN 'Lock Contention'
        WHEN ws.WaitCategory LIKE '%LATCH%' THEN 'Latch Contention'
        WHEN ws.WaitCategory LIKE '%NETWORK%' THEN 'Network'
        ELSE 'Other'
    END AS WaitCategoryGroup,
    SUM(ws.TotalWaitTimeMs) AS TotalWaitTimeMs,
    SUM(ws.TotalWaitTimeMs) / 1000.0 / 60.0 AS TotalWaitTimeMinutes,
    SUM(ws.CountWaits) AS TotalWaits,
    AVG(ws.AvgWaitTimeMs) AS AvgWaitTimeMs,
    MAX(ws.MaxWaitTimeMs) AS MaxWaitTimeMs
FROM qsh.QueryStoreWaitStats ws
GROUP BY 
    ws.TenantName,
    ws.ServerName,
    ws.DatabaseName,
    ws.WaitCategory
GO

PRINT 'Data Modeling Views Created Successfully'
PRINT 'Dimension Views: 4'
PRINT 'Fact Views: 4'
GO
