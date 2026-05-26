-- FactTopQueries: Pre-aggregated top queries for dashboard performance
CREATE VIEW [qsh].[FactTopQueries] AS
SELECT TOP 1000
    rs.[TenantName],
    rs.[ServerName],
    rs.[DatabaseName],
    rs.[QueryId],
    dq.[QueryText],
    SUM(rs.[CountExecutions]) AS TotalExecutions,
    AVG(rs.[AvgDurationMs]) AS AvgDurationMs,
    MAX(rs.[MaxDurationMs]) AS MaxDurationMs,
    SUM(rs.[CountExecutions] * rs.[AvgDurationMs]) / 1000.0 AS TotalDurationSeconds,
    AVG(rs.[AvgCpuTimeMs]) AS AvgCpuTimeMs,
    SUM(rs.[AvgLogicalIoReads]) AS AvgLogicalIoReads,
    AVG(rs.[AvgMemoryUsedMb]) AS AvgMemoryUsedMb,
    COUNT(DISTINCT rs.[RuntimeStatsIntervalId]) AS IntervalsObserved
FROM [qsh].[QueryStoreRuntimeStats] rs
LEFT JOIN [qsh].[DimQuery] dq 
    ON rs.[QueryId] = dq.[QueryId] 
    AND rs.[TenantName] = dq.[TenantName] 
    AND rs.[ServerName] = dq.[ServerName]
    AND rs.[DatabaseName] = dq.[DatabaseName]
GROUP BY 
    rs.[TenantName],
    rs.[ServerName],
    rs.[DatabaseName],
    rs.[QueryId],
    dq.[QueryText]
ORDER BY TotalDurationSeconds DESC
GO
