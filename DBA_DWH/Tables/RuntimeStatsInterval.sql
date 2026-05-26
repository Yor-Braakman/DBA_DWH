-- RuntimeStatsInterval: Time dimension for aggregation intervals
-- Primary Key: (TenantName, ServerName, RuntimeStatsIntervalId) for tenant/server granularity
CREATE TABLE [qsh].[RuntimeStatsInterval] (
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [RuntimeStatsIntervalId] INT NOT NULL,
    [IntervalStartTime] DATETIME2(7) NOT NULL,
    [IntervalEndTime] DATETIME2(7) NOT NULL,
    [IntervalDurationMinutes] INT NOT NULL,
    [CapturedDate] DATE NOT NULL,
    [CapturedTime] TIME(7) NOT NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT [PK_RuntimeStatsInterval] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [RuntimeStatsIntervalId] ASC)
)
GO

-- Supporting indexes
CREATE NONCLUSTERED INDEX [IX_RuntimeStatsInterval_StartTime] 
    ON [qsh].[RuntimeStatsInterval]([IntervalStartTime])
    INCLUDE ([IntervalEndTime], [CapturedDate])
GO
