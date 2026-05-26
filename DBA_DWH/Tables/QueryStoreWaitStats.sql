-- QueryStoreWaitStats: Wait statistics by category (FACT table)
-- Primary Key: (TenantName, ServerName, DatabaseName, WaitStatsId, RuntimeStatsIntervalId)
-- Clustered on multi-tenant columns first for better partitioning/filtering
CREATE TABLE [qsh].[QueryStoreWaitStats] (
    [WaitStatsId] BIGINT NOT NULL IDENTITY(1,1),
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [RuntimeStatsIntervalId] INT NOT NULL,
    [QueryId] BIGINT NOT NULL,
    [PlanId] BIGINT NOT NULL,
    [WaitCategory] NVARCHAR(128) NOT NULL,
    [WaitCategoryId] INT NOT NULL,
    [TotalWaitTimeMs] BIGINT NOT NULL,
    [AvgWaitTimeMs] FLOAT NOT NULL,
    [MaxWaitTimeMs] BIGINT NOT NULL,
    [QueryWaitTimeCategory] INT NOT NULL,
    [CountWaits] BIGINT NOT NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT [PK_QueryStoreWaitStats] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [WaitStatsId] ASC, [RuntimeStatsIntervalId] ASC)
)
GO

-- Supporting indexes
CREATE NONCLUSTERED INDEX [IX_WaitStats_Category]
    ON [qsh].[QueryStoreWaitStats]([TenantName], [ServerName], [DatabaseName], [WaitCategory], [TotalWaitTimeMs] DESC)
    INCLUDE ([CountWaits], [AvgWaitTimeMs], [QueryId])
GO

CREATE NONCLUSTERED INDEX [IX_WaitStats_Query]
    ON [qsh].[QueryStoreWaitStats]([TenantName], [ServerName], [DatabaseName], [QueryId], [PlanId])
    INCLUDE ([RuntimeStatsIntervalId], [WaitCategory], [TotalWaitTimeMs])
GO

CREATE NONCLUSTERED INDEX [IX_WaitStats_Interval]
    ON [qsh].[QueryStoreWaitStats]([TenantName], [ServerName], [DatabaseName], [RuntimeStatsIntervalId])
    INCLUDE ([QueryId], [PlanId], [WaitCategory], [TotalWaitTimeMs])
GO
