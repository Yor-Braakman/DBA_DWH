-- sp_MERGE_QueryDimensions: UPDATE/INSERT pattern for dimension tables
-- Handles: Query, QueryText, Plan, RuntimeStatsInterval
CREATE PROCEDURE [qsh].[sp_MERGE_QueryDimensions]
    @TenantName NVARCHAR(128),
    @ServerName NVARCHAR(128),
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @recordsInserted INT = 0
    DECLARE @recordsUpdated INT = 0

    BEGIN TRANSACTION

    -- ============================================
    -- UPDATE/INSERT: QueryStoreQuery
    -- ============================================
    
    -- UPDATE existing QueryStoreQuery records
    UPDATE tgt
    SET tgt.[CompilationCount] = src.[CompilationCount],
        tgt.[AvgCompileCpuTimeMs] = src.[AvgCompileCpuTimeMs],
        tgt.[MaxCompileCpuTimeMs] = src.[MaxCompileCpuTimeMs],
        tgt.[AvgCompileMemoryMb] = src.[AvgCompileMemoryMb],
        tgt.[MaxCompileMemoryMb] = src.[MaxCompileMemoryMb],
        tgt.[CompilationEndTime] = src.[CompilationEndTime],
        tgt.[LastCompilationBatchUTC] = src.[LastCompilationBatchUTC]
    FROM [qsh].[QueryStoreQuery] tgt
    INNER JOIN [qsh].[QueryStoreQuery] src
        ON tgt.[TenantName] = src.[TenantName]
        AND tgt.[ServerName] = src.[ServerName]
        AND tgt.[DatabaseName] = src.[DatabaseName]
        AND tgt.[QueryId] = src.[QueryId]
    WHERE tgt.[TenantName] = @TenantName 
      AND tgt.[ServerName] = @ServerName
      AND tgt.[DatabaseName] = @DatabaseName

    SET @recordsUpdated = @recordsUpdated + @@ROWCOUNT

    -- INSERT new QueryStoreQuery records
    INSERT INTO [qsh].[QueryStoreQuery] (
        [TenantName], [ServerName], [DatabaseName], [QueryId],
        [QueryTextId], [ContextSettingsId], [ObjectId],
        [CompilationStartTime], [CompilationEndTime],
        [LastCompilationBatch], [LastCompilationBatchUTC],
        [CompilationCount], [AvgCompileCpuTimeMs], [MaxCompileCpuTimeMs],
        [AvgCompileMemoryMb], [MaxCompileMemoryMb]
    )
    SELECT 
        src.[TenantName], src.[ServerName], src.[DatabaseName], src.[QueryId],
        src.[QueryTextId], src.[ContextSettingsId], src.[ObjectId],
        src.[CompilationStartTime], src.[CompilationEndTime],
        src.[LastCompilationBatch], src.[LastCompilationBatchUTC],
        src.[CompilationCount], src.[AvgCompileCpuTimeMs], src.[MaxCompileCpuTimeMs],
        src.[AvgCompileMemoryMb], src.[MaxCompileMemoryMb]
    FROM [qsh].[QueryStoreQuery] src
    WHERE src.[TenantName] = @TenantName 
      AND src.[ServerName] = @ServerName
      AND src.[DatabaseName] = @DatabaseName
      AND NOT EXISTS (
          SELECT 1
          FROM [qsh].[QueryStoreQuery] tgt
          WHERE tgt.[TenantName] = src.[TenantName]
            AND tgt.[ServerName] = src.[ServerName]
            AND tgt.[DatabaseName] = src.[DatabaseName]
            AND tgt.[QueryId] = src.[QueryId]
      )

    SET @recordsInserted = @recordsInserted + @@ROWCOUNT

    -- ============================================
    -- INSERT ONLY: QueryStoreQueryText (immutable)
    -- ============================================
    INSERT INTO [qsh].[QueryStoreQueryText] (
        [TenantName], [ServerName], [DatabaseName], [QueryTextId],
        [QueryTextContent], [StatementType], [QueryHash], [QueryPlanHash]
    )
    SELECT 
        src.[TenantName], src.[ServerName], src.[DatabaseName], src.[QueryTextId],
        src.[QueryTextContent], src.[StatementType], src.[QueryHash], src.[QueryPlanHash]
    FROM [qsh].[QueryStoreQueryText] src
    WHERE src.[TenantName] = @TenantName 
      AND src.[ServerName] = @ServerName
      AND src.[DatabaseName] = @DatabaseName
      AND NOT EXISTS (
          SELECT 1
          FROM [qsh].[QueryStoreQueryText] tgt
          WHERE tgt.[TenantName] = src.[TenantName]
            AND tgt.[ServerName] = src.[ServerName]
            AND tgt.[DatabaseName] = src.[DatabaseName]
            AND tgt.[QueryTextId] = src.[QueryTextId]
      )

    SET @recordsInserted = @recordsInserted + @@ROWCOUNT

    -- ============================================
    -- UPDATE/INSERT: QueryStorePlan
    -- ============================================
    
    -- UPDATE existing QueryStorePlan records
    UPDATE tgt
    SET tgt.[LastExecutionTime] = src.[LastExecutionTime]
    FROM [qsh].[QueryStorePlan] tgt
    INNER JOIN [qsh].[QueryStorePlan] src
        ON tgt.[TenantName] = src.[TenantName]
        AND tgt.[ServerName] = src.[ServerName]
        AND tgt.[DatabaseName] = src.[DatabaseName]
        AND tgt.[PlanId] = src.[PlanId]
    WHERE tgt.[TenantName] = @TenantName 
      AND tgt.[ServerName] = @ServerName
      AND tgt.[DatabaseName] = @DatabaseName

    SET @recordsUpdated = @recordsUpdated + @@ROWCOUNT

    -- INSERT new QueryStorePlan records
    INSERT INTO [qsh].[QueryStorePlan] (
        [TenantName], [ServerName], [DatabaseName], [PlanId],
        [QueryId], [EngineVersion], [CompatibilityLevel],
        [QueryPlanHash], [QueryHash], [PlanHandle],
        [CreationTime], [LastExecutionTime],
        [QueryPlanCompressed], [QueryPlanText],
        [IsOnlineIndexPlan], [IsParallelizable]
    )
    SELECT 
        src.[TenantName], src.[ServerName], src.[DatabaseName], src.[PlanId],
        src.[QueryId], src.[EngineVersion], src.[CompatibilityLevel],
        src.[QueryPlanHash], src.[QueryHash], src.[PlanHandle],
        src.[CreationTime], src.[LastExecutionTime],
        src.[QueryPlanCompressed], src.[QueryPlanText],
        src.[IsOnlineIndexPlan], src.[IsParallelizable]
    FROM [qsh].[QueryStorePlan] src
    WHERE src.[TenantName] = @TenantName 
      AND src.[ServerName] = @ServerName
      AND src.[DatabaseName] = @DatabaseName
      AND NOT EXISTS (
          SELECT 1
          FROM [qsh].[QueryStorePlan] tgt
          WHERE tgt.[TenantName] = src.[TenantName]
            AND tgt.[ServerName] = src.[ServerName]
            AND tgt.[DatabaseName] = src.[DatabaseName]
            AND tgt.[PlanId] = src.[PlanId]
      )

    SET @recordsInserted = @recordsInserted + @@ROWCOUNT

    -- INSERT ONLY: RuntimeStatsInterval (immutable)

    INSERT INTO [qsh].[RuntimeStatsInterval] (
        [TenantName], [ServerName], [RuntimeStatsIntervalId],
        [IntervalStartTime], [IntervalEndTime], [IntervalDurationMinutes],
        [CapturedDate], [CapturedTime]
    )
    SELECT 
        src.[TenantName], src.[ServerName], src.[RuntimeStatsIntervalId],
        src.[IntervalStartTime], src.[IntervalEndTime], src.[IntervalDurationMinutes],
        src.[CapturedDate], src.[CapturedTime]
    FROM [qsh].[RuntimeStatsInterval] src
    WHERE src.[TenantName] = @TenantName 
      AND src.[ServerName] = @ServerName
      AND NOT EXISTS (
          SELECT 1
          FROM [qsh].[RuntimeStatsInterval] tgt
          WHERE tgt.[TenantName] = src.[TenantName]
            AND tgt.[ServerName] = src.[ServerName]
            AND tgt.[RuntimeStatsIntervalId] = src.[RuntimeStatsIntervalId]
      )

    SET @recordsInserted = @recordsInserted + @@ROWCOUNT

    COMMIT TRANSACTION

    -- Log results to ETLControl
    INSERT INTO [qsh].[ETLControl] (
        [TenantName], [ServerName], [DatabaseName], 
        [LastExtractTime], [ExtractDurationSeconds], 
        [RecordsInserted], [RecordsUpdated], [ExtractStatus]
    )
    VALUES (
        @TenantName, @ServerName, @DatabaseName, 
        GETUTC(), 0, @recordsInserted, @recordsUpdated, 'SUCCESS'
    )

    SELECT @recordsInserted AS RecordsInserted, @recordsUpdated AS RecordsUpdated

END
GO
