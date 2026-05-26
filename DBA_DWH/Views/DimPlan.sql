-- DimPlan: Execution plan details with age calculations
CREATE VIEW [qsh].[DimPlan] AS
SELECT 
    CONCAT(p.[TenantName], '_', p.[ServerName], '_', p.[DatabaseName], '_', p.[PlanId]) AS PlanDimKey,
    p.[TenantName],
    p.[ServerName],
    p.[DatabaseName],
    p.[PlanId],
    p.[QueryId],
    p.[EngineVersion],
    p.[CompatibilityLevel],
    p.[QueryHash],
    p.[QueryPlanHash],
    p.[PlanHandle],
    p.[CreationTime],
    p.[LastExecutionTime],
    DATEDIFF(DAY, p.[CreationTime], p.[LastExecutionTime]) AS PlanAgeInDays,
    p.[IsOnlineIndexPlan],
    p.[IsParallelizable],
    CASE 
        WHEN p.[QueryPlanCompressed] IS NOT NULL THEN 'Compressed'
        WHEN p.[QueryPlanText] IS NOT NULL THEN 'XML'
        ELSE 'Unknown'
    END AS PlanStorage,
    p.[LoadDate]
FROM [qsh].[QueryStorePlan] p
GO
