-- FactWaitStats: Wait statistics by category
CREATE VIEW [qsh].[FactWaitStats] AS
SELECT 
    ws.[WaitStatsId],
    CONCAT(ws.[TenantName], '_', ws.[ServerName], '_', ws.[DatabaseName], '_', ws.[QueryId]) AS QueryDimKey,
    ws.[RuntimeStatsIntervalId],
    ws.[TenantName],
    ws.[ServerName],
    ws.[DatabaseName],
    ws.[QueryId],
    ws.[PlanId],
    ws.[WaitCategory],
    ws.[WaitCategoryId],
    CASE 
        WHEN ws.[WaitCategory] LIKE '%CPU%' THEN 'CPU Contention'
        WHEN ws.[WaitCategory] LIKE '%MEMORY%' OR ws.[WaitCategory] LIKE '%RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN ws.[WaitCategory] LIKE '%IO%' OR ws.[WaitCategory] LIKE '%PAGEIO%' THEN 'IO Contention'
        WHEN ws.[WaitCategory] LIKE '%LOCK%' THEN 'Lock Contention'
        WHEN ws.[WaitCategory] LIKE '%LATCH%' THEN 'Latch Contention'
        WHEN ws.[WaitCategory] LIKE '%NETWORK%' THEN 'Network'
        ELSE 'Other'
    END AS WaitCategoryGroup,
    ws.[TotalWaitTimeMs],
    ws.[TotalWaitTimeMs] / 1000.0 / 60.0 AS TotalWaitTimeMinutes,
    ws.[AvgWaitTimeMs],
    ws.[MaxWaitTimeMs],
    ws.[CountWaits],
    ws.[QueryWaitTimeCategory],
    ws.[LoadDate]
FROM [qsh].[QueryStoreWaitStats] ws
GO
