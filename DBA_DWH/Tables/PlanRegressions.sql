-- PlanRegressions: Detected plan regressions with SCD Type 2 tracking
-- Primary Key: (TenantName, ServerName, DatabaseName, RegressionId)
-- Provides queryable history of performance degradation events
CREATE TABLE [qsh].[PlanRegressions] (
    [RegressionId] BIGINT NOT NULL IDENTITY(1,1),
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [QueryId] BIGINT NOT NULL,
    [OldPlanId] BIGINT NOT NULL,
    [NewPlanId] BIGINT NOT NULL,
    [OldAvgDurationMs] FLOAT NOT NULL,
    [NewAvgDurationMs] FLOAT NOT NULL,
    [DurationChangePercentage] FLOAT NOT NULL,
    [DetectionDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    [IsInvestigated] BIT NOT NULL DEFAULT 0,
    [Notes] NVARCHAR(MAX) NULL,
    CONSTRAINT [PK_PlanRegressions] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [RegressionId] ASC)
)
GO

-- Index for finding recent regressions
CREATE NONCLUSTERED INDEX [IX_PlanRegressions_Detection]
    ON [qsh].[PlanRegressions]([TenantName], [ServerName], [DatabaseName], [DetectionDate] DESC)
    INCLUDE ([QueryId], [DurationChangePercentage], [IsInvestigated])
GO

-- Index for finding uninvestigated regressions
CREATE NONCLUSTERED INDEX [IX_PlanRegressions_Uninvestigated]
    ON [qsh].[PlanRegressions]([TenantName], [ServerName], [DatabaseName], [IsInvestigated])
    WHERE [IsInvestigated] = 0
GO

-- Index for query regression history
CREATE NONCLUSTERED INDEX [IX_PlanRegressions_Query]
    ON [qsh].[PlanRegressions]([TenantName], [ServerName], [DatabaseName], [QueryId])
    INCLUDE ([OldPlanId], [NewPlanId], [DurationChangePercentage], [DetectionDate])
GO
