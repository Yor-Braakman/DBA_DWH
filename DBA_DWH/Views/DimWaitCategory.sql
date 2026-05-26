-- DimWaitCategory: Wait categories reference
CREATE VIEW [qsh].[DimWaitCategory] AS
SELECT DISTINCT
    [WaitCategoryId],
    [WaitCategory],
    CASE 
        WHEN [WaitCategory] LIKE '%CPU%' THEN 'CPU Contention'
        WHEN [WaitCategory] LIKE '%MEMORY%' OR [WaitCategory] LIKE '%RESOURCE_SEMAPHORE%' THEN 'Memory Pressure'
        WHEN [WaitCategory] LIKE '%IO%' OR [WaitCategory] LIKE '%PAGEIO%' THEN 'IO Contention'
        WHEN [WaitCategory] LIKE '%LOCK%' THEN 'Lock Contention'
        WHEN [WaitCategory] LIKE '%LATCH%' THEN 'Latch Contention'
        WHEN [WaitCategory] LIKE '%NETWORK%' THEN 'Network'
        ELSE 'Other'
    END AS WaitCategoryGroup
FROM [qsh].[QueryStoreWaitStats]
GO
