-- QueryStoreRuntimeStats: Execution statistics per interval (FACT table)
-- Primary Key: (TenantName, ServerName, DatabaseName, RuntimeStatsId, RuntimeStatsIntervalId)
-- Clustered on multi-tenant columns first for better partitioning/filtering
CREATE TABLE [qsh].[QueryStoreRuntimeStats] (
    [RuntimeStatsId] BIGINT NOT NULL IDENTITY(1,1),
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [RuntimeStatsIntervalId] INT NOT NULL,
    [QueryId] BIGINT NOT NULL,
    [PlanId] BIGINT NOT NULL,
    [ExecutionType] INT NOT NULL,
    [ExecutionTypeDesc] NVARCHAR(128) NOT NULL,
    [CountExecutions] BIGINT NOT NULL,
    [AvgDurationMs] FLOAT NOT NULL,
    [MaxDurationMs] FLOAT NOT NULL,
    [MinDurationMs] FLOAT NOT NULL,
    [StdevDurationMs] FLOAT NULL,
    [AvgLogicalIoReads] BIGINT NOT NULL,
    [MaxLogicalIoReads] BIGINT NOT NULL,
    [MinLogicalIoReads] BIGINT NOT NULL,
    [AvgLogicalIoWrites] BIGINT NOT NULL,
    [MaxLogicalIoWrites] BIGINT NOT NULL,
    [MinLogicalIoWrites] BIGINT NOT NULL,
    [AvgPhysicalIoReads] BIGINT NOT NULL,
    [MaxPhysicalIoReads] BIGINT NOT NULL,
    [MinPhysicalIoReads] BIGINT NOT NULL,
    [AvgCpuTimeMs] FLOAT NOT NULL,
    [MaxCpuTimeMs] FLOAT NOT NULL,
    [MinCpuTimeMs] FLOAT NOT NULL,
    [AvgClrTimeMs] FLOAT NOT NULL,
    [MaxClrTimeMs] FLOAT NOT NULL,
    [MinClrTimeMs] FLOAT NOT NULL,
    [AvgElapsedTimeMs] FLOAT NOT NULL,
    [MaxElapsedTimeMs] FLOAT NOT NULL,
    [MinElapsedTimeMs] FLOAT NOT NULL,
    [AvgMemoryUsedMb] FLOAT NOT NULL,
    [MaxMemoryUsedMb] FLOAT NOT NULL,
    [MinMemoryUsedMb] FLOAT NOT NULL,
    [AvgRowCount] FLOAT NOT NULL,
    [MaxRowCount] BIGINT NOT NULL,
    [MinRowCount] BIGINT NOT NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    [IsRegression] BIT NOT NULL DEFAULT 0,
    CONSTRAINT [PK_QueryStoreRuntimeStats] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [RuntimeStatsId] ASC, [RuntimeStatsIntervalId] ASC)
)
GO

-- Supporting indexes optimized for analysis queries
CREATE NONCLUSTERED INDEX [IX_RuntimeStats_Query]
    ON [qsh].[QueryStoreRuntimeStats]([TenantName], [ServerName], [DatabaseName], [QueryId], [PlanId])
    INCLUDE ([RuntimeStatsIntervalId], [AvgDurationMs], [CountExecutions])
GO

CREATE NONCLUSTERED INDEX [IX_RuntimeStats_Performance]
    ON [qsh].[QueryStoreRuntimeStats]([TenantName], [ServerName], [AvgDurationMs] DESC, [MaxDurationMs] DESC)
    INCLUDE ([QueryId], [PlanId], [CountExecutions], [IsRegression])
GO

CREATE NONCLUSTERED INDEX [IX_RuntimeStats_Interval]
    ON [qsh].[QueryStoreRuntimeStats]([TenantName], [ServerName], [DatabaseName], [RuntimeStatsIntervalId])
    INCLUDE ([QueryId], [PlanId], [AvgDurationMs], [CountExecutions])
GO

CREATE NONCLUSTERED INDEX [IX_RuntimeStats_Regression]
    ON [qsh].[QueryStoreRuntimeStats]([TenantName], [ServerName], [IsRegression])
    WHERE [IsRegression] = 1
GO
