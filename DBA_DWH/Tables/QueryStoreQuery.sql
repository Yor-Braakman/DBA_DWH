-- QueryStoreQuery: Query definitions and compilation statistics
-- Primary Key: (TenantName, ServerName, DatabaseName, QueryId) for multi-tenant granularity
CREATE TABLE [qsh].[QueryStoreQuery] (
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [QueryId] BIGINT NOT NULL,
    [QueryTextId] BIGINT NOT NULL,
    [ContextSettingsId] BIGINT NOT NULL,
    [ObjectId] BIGINT NULL,
    [CompilationStartTime] DATETIME2(7) NOT NULL,
    [CompilationEndTime] DATETIME2(7) NOT NULL,
    [LastCompilationBatch] BIGINT NOT NULL,
    [LastCompilationBatchUTC] DATETIME2(7) NOT NULL,
    [CompilationCount] BIGINT NOT NULL,
    [AvgCompileCpuTimeMs] FLOAT NOT NULL,
    [MaxCompileCpuTimeMs] FLOAT NOT NULL,
    [AvgCompileMemoryMb] FLOAT NOT NULL,
    [MaxCompileMemoryMb] FLOAT NOT NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT [PK_QueryStoreQuery] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [QueryId] ASC)
)
GO

-- Supporting indexes
CREATE NONCLUSTERED INDEX [IX_QueryStoreQuery_ContextSettings] 
    ON [qsh].[QueryStoreQuery]([ContextSettingsId])
    INCLUDE ([QueryId], [ObjectId])
GO

CREATE NONCLUSTERED INDEX [IX_QueryStoreQuery_ObjectId]
    ON [qsh].[QueryStoreQuery]([ObjectId])
    WHERE [ObjectId] IS NOT NULL
GO
