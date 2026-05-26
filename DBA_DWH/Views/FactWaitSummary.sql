-- FactWaitSummary: Aggregated wait statistics by category
CREATE VIEW [qsh].[FactWaitSummary] AS
SELECT 
    ws.[TenantName],
    ws.[ServerName],
    ws.[DatabaseName],
    ws.[WaitCategory],
    CASE 
        WHEN ws.[WaitCategory] LIKE '%CPU%' THEN 'CPU Contention'
        WHEN ws.[WaitCategory] LIKE '%MEMORY%' OR ws.[WaitCategory] LIKE '%RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN ws.[WaitCategory] LIKE '%IO%' OR ws.[WaitCategory] LIKE '%PAGEIO%' THEN 'IO Contention'
        WHEN ws.[WaitCategory] LIKE '%LOCK%' THEN 'Lock Contention'
        WHEN ws.[WaitCategory] LIKE '%LATCH%' THEN 'Latch Contention'
        WHEN ws.[WaitCategory] LIKE '%NETWORK%' THEN 'Network'
        ELSE 'Other'
    END AS WaitCategoryGroup,
    SUM(ws.[TotalWaitTimeMs]) AS TotalWaitTimeMs,
    SUM(ws.[TotalWaitTimeMs]) / 1000.0 / 60.0 AS TotalWaitTimeMinutes,
    SUM(ws.[CountWaits]) AS TotalWaits,
    AVG(ws.[AvgWaitTimeMs]) AS AvgWaitTimeMs,
    MAX(ws.[MaxWaitTimeMs]) AS MaxWaitTimeMs
FROM [qsh].[QueryStoreWaitStats] ws
GROUP BY 
    ws.[TenantName],
    ws.[ServerName],
    ws.[DatabaseName],
    ws.[WaitCategory]
GO
