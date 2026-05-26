-- sp_MERGE_QueryStoreRuntimeStats: UPDATE/INSERT with SCD Type 2 and regression detection
-- Traditional pattern: UPDATE existing, INSERT new, wrapped in transaction
-- Supports tenant/server/database granularity
CREATE PROCEDURE [qsh].[sp_MERGE_QueryStoreRuntimeStats]
    @TenantName NVARCHAR(128),
    @ServerName NVARCHAR(128),
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @recordsInserted INT = 0
    DECLARE @recordsUpdated INT = 0
    DECLARE @recordsRegression INT = 0
    
    BEGIN TRANSACTION

    -- UPDATE existing runtime statistics
    UPDATE tgt
    SET tgt.[CountExecutions] = src.[CountExecutions],
        tgt.[AvgDurationMs] = src.[AvgDurationMs],
        tgt.[MaxDurationMs] = src.[MaxDurationMs],
        tgt.[MinDurationMs] = src.[MinDurationMs],
        tgt.[StdevDurationMs] = src.[StdevDurationMs],
        tgt.[AvgLogicalIoReads] = src.[AvgLogicalIoReads],
        tgt.[MaxLogicalIoReads] = src.[MaxLogicalIoReads],
        tgt.[MinLogicalIoReads] = src.[MinLogicalIoReads],
        tgt.[AvgLogicalIoWrites] = src.[AvgLogicalIoWrites],
        tgt.[MaxLogicalIoWrites] = src.[MaxLogicalIoWrites],
        tgt.[MinLogicalIoWrites] = src.[MinLogicalIoWrites],
        tgt.[AvgPhysicalIoReads] = src.[AvgPhysicalIoReads],
        tgt.[MaxPhysicalIoReads] = src.[MaxPhysicalIoReads],
        tgt.[MinPhysicalIoReads] = src.[MinPhysicalIoReads],
        tgt.[AvgCpuTimeMs] = src.[AvgCpuTimeMs],
        tgt.[MaxCpuTimeMs] = src.[MaxCpuTimeMs],
        tgt.[MinCpuTimeMs] = src.[MinCpuTimeMs],
        tgt.[AvgClrTimeMs] = src.[AvgClrTimeMs],
        tgt.[MaxClrTimeMs] = src.[MaxClrTimeMs],
        tgt.[MinClrTimeMs] = src.[MinClrTimeMs],
        tgt.[AvgElapsedTimeMs] = src.[AvgElapsedTimeMs],
        tgt.[MaxElapsedTimeMs] = src.[MaxElapsedTimeMs],
        tgt.[MinElapsedTimeMs] = src.[MinElapsedTimeMs],
        tgt.[AvgMemoryUsedMb] = src.[AvgMemoryUsedMb],
        tgt.[MaxMemoryUsedMb] = src.[MaxMemoryUsedMb],
        tgt.[MinMemoryUsedMb] = src.[MinMemoryUsedMb],
        tgt.[AvgRowCount] = src.[AvgRowCount],
        tgt.[MaxRowCount] = src.[MaxRowCount],
        tgt.[MinRowCount] = src.[MinRowCount]
    FROM [qsh].[QueryStoreRuntimeStats] tgt
    INNER JOIN [qsh].[QueryStoreRuntimeStats] src
        ON tgt.[TenantName] = src.[TenantName]
        AND tgt.[ServerName] = src.[ServerName]
        AND tgt.[DatabaseName] = src.[DatabaseName]
        AND tgt.[RuntimeStatsIntervalId] = src.[RuntimeStatsIntervalId]
        AND tgt.[QueryId] = src.[QueryId]
        AND tgt.[PlanId] = src.[PlanId]
        AND tgt.[ExecutionType] = src.[ExecutionType]
    WHERE tgt.[TenantName] = @TenantName 
      AND tgt.[ServerName] = @ServerName
      AND tgt.[DatabaseName] = @DatabaseName
    
    SET @recordsUpdated = @@ROWCOUNT

    -- INSERT new runtime statistics (those that don't exist yet)
    INSERT INTO [qsh].[QueryStoreRuntimeStats] (
        [TenantName], [ServerName], [DatabaseName], [RuntimeStatsIntervalId],
        [QueryId], [PlanId], [ExecutionType], [ExecutionTypeDesc],
        [CountExecutions], [AvgDurationMs], [MaxDurationMs], [MinDurationMs], [StdevDurationMs],
        [AvgLogicalIoReads], [MaxLogicalIoReads], [MinLogicalIoReads],
        [AvgLogicalIoWrites], [MaxLogicalIoWrites], [MinLogicalIoWrites],
        [AvgPhysicalIoReads], [MaxPhysicalIoReads], [MinPhysicalIoReads],
        [AvgCpuTimeMs], [MaxCpuTimeMs], [MinCpuTimeMs],
        [AvgClrTimeMs], [MaxClrTimeMs], [MinClrTimeMs],
        [AvgElapsedTimeMs], [MaxElapsedTimeMs], [MinElapsedTimeMs],
        [AvgMemoryUsedMb], [MaxMemoryUsedMb], [MinMemoryUsedMb],
        [AvgRowCount], [MaxRowCount], [MinRowCount]
    )
    SELECT 
        src.[TenantName], src.[ServerName], src.[DatabaseName], src.[RuntimeStatsIntervalId],
        src.[QueryId], src.[PlanId], src.[ExecutionType], src.[ExecutionTypeDesc],
        src.[CountExecutions], src.[AvgDurationMs], src.[MaxDurationMs], src.[MinDurationMs], src.[StdevDurationMs],
        src.[AvgLogicalIoReads], src.[MaxLogicalIoReads], src.[MinLogicalIoReads],
        src.[AvgLogicalIoWrites], src.[MaxLogicalIoWrites], src.[MinLogicalIoWrites],
        src.[AvgPhysicalIoReads], src.[MaxPhysicalIoReads], src.[MinPhysicalIoReads],
        src.[AvgCpuTimeMs], src.[MaxCpuTimeMs], src.[MinCpuTimeMs],
        src.[AvgClrTimeMs], src.[MaxClrTimeMs], src.[MinClrTimeMs],
        src.[AvgElapsedTimeMs], src.[MaxElapsedTimeMs], src.[MinElapsedTimeMs],
        src.[AvgMemoryUsedMb], src.[MaxMemoryUsedMb], src.[MinMemoryUsedMb],
        src.[AvgRowCount], src.[MaxRowCount], src.[MinRowCount]
    FROM [qsh].[QueryStoreRuntimeStats] src
    WHERE src.[TenantName] = @TenantName 
      AND src.[ServerName] = @ServerName
      AND src.[DatabaseName] = @DatabaseName
      AND NOT EXISTS (
          SELECT 1
          FROM [qsh].[QueryStoreRuntimeStats] tgt
          WHERE tgt.[TenantName] = src.[TenantName]
            AND tgt.[ServerName] = src.[ServerName]
            AND tgt.[DatabaseName] = src.[DatabaseName]
            AND tgt.[RuntimeStatsIntervalId] = src.[RuntimeStatsIntervalId]
            AND tgt.[QueryId] = src.[QueryId]
            AND tgt.[PlanId] = src.[PlanId]
            AND tgt.[ExecutionType] = src.[ExecutionType]
      )

    SET @recordsInserted = @@ROWCOUNT

    -- Detect plan regressions per tenant/server/database
    INSERT INTO [qsh].[PlanRegressions] (
        [TenantName], [ServerName], [DatabaseName], [QueryId], 
        [OldPlanId], [NewPlanId], [OldAvgDurationMs], [NewAvgDurationMs], 
        [DurationChangePercentage]
    )
    SELECT 
        rh.[TenantName],
        rh.[ServerName],
        rh.[DatabaseName],
        rh.[QueryId],
        rh.[PlanId] AS OldPlanId,
        rs.[PlanId] AS NewPlanId,
        AVG(rh.[AvgDurationMs]) AS OldAvgDurationMs,
        AVG(rs.[AvgDurationMs]) AS NewAvgDurationMs,
        ((AVG(rs.[AvgDurationMs]) - AVG(rh.[AvgDurationMs])) / NULLIF(AVG(rh.[AvgDurationMs]), 0)) * 100 AS DurationChangePercentage
    FROM [qsh].[QueryStoreRuntimeStats] AS rh
    INNER JOIN [qsh].[QueryStoreRuntimeStats] AS rs
        ON rh.[QueryId] = rs.[QueryId]
        AND rh.[TenantName] = rs.[TenantName]
        AND rh.[ServerName] = rs.[ServerName]
        AND rh.[DatabaseName] = rs.[DatabaseName]
    WHERE rh.[TenantName] = @TenantName 
      AND rh.[ServerName] = @ServerName
      AND rh.[DatabaseName] = @DatabaseName
      AND rh.[PlanId] <> rs.[PlanId]
      AND rh.[RuntimeStatsIntervalId] < rs.[RuntimeStatsIntervalId]
      AND ((AVG(rs.[AvgDurationMs]) - AVG(rh.[AvgDurationMs])) / NULLIF(AVG(rh.[AvgDurationMs]), 0)) > 0.25
      AND NOT EXISTS (
          SELECT 1 FROM [qsh].[PlanRegressions] pr
          WHERE pr.[QueryId] = rh.[QueryId]
            AND pr.[TenantName] = rh.[TenantName]
            AND pr.[ServerName] = rh.[ServerName]
            AND pr.[DatabaseName] = rh.[DatabaseName]
            AND pr.[OldPlanId] = rh.[PlanId]
            AND pr.[NewPlanId] = rs.[PlanId]
            AND DATEDIFF(DAY, pr.[DetectionDate], GETUTC()) < 1
      )
    GROUP BY 
        rh.[TenantName], rh.[ServerName], rh.[DatabaseName], rh.[QueryId], 
        rh.[PlanId], rs.[PlanId]

    SET @recordsRegression = @@ROWCOUNT
    
    -- Update IsRegression flag
    UPDATE [qsh].[QueryStoreRuntimeStats]
    SET [IsRegression] = 1
    WHERE EXISTS (
        SELECT 1 FROM [qsh].[PlanRegressions] pr
        WHERE pr.[QueryId] = [qsh].[QueryStoreRuntimeStats].[QueryId]
          AND pr.[NewPlanId] = [qsh].[QueryStoreRuntimeStats].[PlanId]
          AND pr.[TenantName] = [qsh].[QueryStoreRuntimeStats].[TenantName]
          AND pr.[ServerName] = [qsh].[QueryStoreRuntimeStats].[ServerName]
          AND pr.[DatabaseName] = [qsh].[QueryStoreRuntimeStats].[DatabaseName]
          AND DATEDIFF(DAY, pr.[DetectionDate], GETUTC()) < 1
    )
    AND [TenantName] = @TenantName
    AND [ServerName] = @ServerName
    AND [DatabaseName] = @DatabaseName

    COMMIT TRANSACTION

    -- Log results
    INSERT INTO [qsh].[ETLControl] (
        [TenantName], [ServerName], [DatabaseName],
        [LastExtractTime], [ExtractDurationSeconds],
        [RecordsInserted], [RecordsUpdated], [ExtractStatus]
    )
    VALUES (
        @TenantName, @ServerName, @DatabaseName,
        GETUTC(), 0,
        @recordsInserted, @recordsUpdated, 'SUCCESS'
    )

    SELECT @recordsInserted AS RecordsInserted, @recordsUpdated AS RecordsUpdated, @recordsRegression AS RegressionsDetected

END
GO
