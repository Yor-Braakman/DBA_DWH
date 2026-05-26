-- QueryStorePlan: Execution plans (XML) and plan metadata
-- Primary Key: (TenantName, ServerName, DatabaseName, PlanId) for multi-tenant granularity
CREATE TABLE [qsh].[QueryStorePlan] (
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [PlanId] BIGINT NOT NULL,
    [QueryId] BIGINT NOT NULL,
    [EngineVersion] NVARCHAR(32) NOT NULL,
    [CompatibilityLevel] INT NOT NULL,
    [QueryPlanHash] BINARY(8) NULL,
    [QueryHash] BINARY(8) NULL,
    [PlanHandle] VARBINARY(64) NULL,
    [CreationTime] DATETIME2(7) NOT NULL,
    [LastExecutionTime] DATETIME2(7) NOT NULL,
    [QueryPlanCompressed] VARBINARY(MAX) NULL,
    [QueryPlanText] XML NULL,
    [IsOnlineIndexPlan] BIT NULL,
    [IsParallelizable] BIT NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT [PK_QueryStorePlan] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [PlanId] ASC)
)
GO

-- Supporting indexes
CREATE NONCLUSTERED INDEX [IX_QueryStorePlan_Hash]
    ON [qsh].[QueryStorePlan]([QueryHash], [QueryPlanHash])
    INCLUDE ([PlanId], [CreationTime])
GO

CREATE NONCLUSTERED INDEX [IX_QueryStorePlan_Query]
    ON [qsh].[QueryStorePlan]([TenantName], [ServerName], [DatabaseName], [QueryId])
    INCLUDE ([PlanId], [CreationTime])
GO
