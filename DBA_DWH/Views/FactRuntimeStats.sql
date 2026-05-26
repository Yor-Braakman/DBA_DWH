-- FactRuntimeStats: Performance metrics per query/plan/interval (aggregated)
CREATE VIEW [qsh].[FactRuntimeStats] AS
SELECT 
    rs.[RuntimeStatsId],
    CONCAT(rs.[TenantName], '_', rs.[ServerName], '_', rs.[DatabaseName], '_', rs.[QueryId]) AS QueryDimKey,
    CONCAT(rs.[TenantName], '_', rs.[ServerName], '_', rs.[DatabaseName], '_', rs.[PlanId]) AS PlanDimKey,
    rs.[RuntimeStatsIntervalId],
    rs.[TenantName],
    rs.[ServerName],
    rs.[DatabaseName],
    rs.[QueryId],
    rs.[PlanId],
    rs.[ExecutionType],
    rs.[ExecutionTypeDesc],
    rs.[CountExecutions],
    rs.[AvgDurationMs],
    rs.[AvgDurationMs] / 1000.0 AS AvgDurationSeconds,
    rs.[MaxDurationMs],
    rs.[MinDurationMs],
    CASE 
        WHEN rs.[StdevDurationMs] IS NULL THEN 0
        ELSE rs.[StdevDurationMs]
    END AS StdevDurationMs,
    rs.[AvgLogicalIoReads],
    rs.[MaxLogicalIoReads],
    rs.[AvgLogicalIoWrites],
    rs.[MaxLogicalIoWrites],
    rs.[AvgPhysicalIoReads],
    rs.[MaxPhysicalIoReads],
    rs.[AvgCpuTimeMs],
    rs.[AvgCpuTimeMs] / 1000.0 AS AvgCpuTimeSeconds,
    rs.[MaxCpuTimeMs],
    rs.[AvgClrTimeMs],
    rs.[MaxClrTimeMs],
    rs.[AvgElapsedTimeMs],
    rs.[MaxElapsedTimeMs],
    rs.[AvgMemoryUsedMb],
    rs.[MaxMemoryUsedMb],
    rs.[AvgRowCount],
    rs.[MaxRowCount],
    rs.[MinRowCount],
    (rs.[AvgCpuTimeMs] / NULLIF(rs.[AvgDurationMs], 0)) * 100.0 AS CpuPercentageOfDuration,
    rs.[IsRegression],
    CASE 
        WHEN rs.[IsRegression] = 1 THEN 'Regression Detected'
        ELSE 'Normal'
    END AS PerformanceStatus,
    rs.[LoadDate]
FROM [qsh].[QueryStoreRuntimeStats] rs
GO
