/*
================================================================================
Query Store ETL - MERGE Statements (SCD Type 2)
Purpose: Incremental updates with plan change detection and regression tracking
Author: GitHub Copilot
Date: 2026-05-26
================================================================================
*/

-- Set database context
-- USE [HistoricalQueryStore]
-- GO

-- ============================================================================
-- MERGE STATEMENTS FOR FACT TABLES
-- ============================================================================

-- 1. MERGE for QueryStoreRuntimeStats with Regression Detection
IF OBJECT_ID('sp_MERGE_QueryStoreRuntimeStats', 'P') IS NOT NULL
    DROP PROCEDURE sp_MERGE_QueryStoreRuntimeStats
GO

CREATE PROCEDURE sp_MERGE_QueryStoreRuntimeStats
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

    -- MERGE to upsert runtime statistics
    MERGE INTO qsh.QueryStoreRuntimeStats AS target
    USING (
        -- Source data from staging table (you would load this first)
        SELECT * FROM qsh.QueryStoreRuntimeStats_Staging
        WHERE TenantName = @TenantName 
          AND ServerName = @ServerName
          AND DatabaseName = @DatabaseName
    ) AS source
    ON (
        target.RuntimeStatsIntervalId = source.RuntimeStatsIntervalId
        AND target.TenantName = source.TenantName
        AND target.ServerName = source.ServerName
        AND target.DatabaseName = source.DatabaseName
        AND target.QueryId = source.QueryId
        AND target.PlanId = source.PlanId
        AND target.ExecutionType = source.ExecutionType
    )
    WHEN MATCHED THEN
        UPDATE SET
            target.CountExecutions = source.CountExecutions,
            target.AvgDurationMs = source.AvgDurationMs,
            target.MaxDurationMs = source.MaxDurationMs,
            target.MinDurationMs = source.MinDurationMs,
            target.StdevDurationMs = source.StdevDurationMs,
            target.AvgLogicalIoReads = source.AvgLogicalIoReads,
            target.MaxLogicalIoReads = source.MaxLogicalIoReads,
            target.MinLogicalIoReads = source.MinLogicalIoReads,
            target.AvgLogicalIoWrites = source.AvgLogicalIoWrites,
            target.MaxLogicalIoWrites = source.MaxLogicalIoWrites,
            target.MinLogicalIoWrites = source.MinLogicalIoWrites,
            target.AvgPhysicalIoReads = source.AvgPhysicalIoReads,
            target.MaxPhysicalIoReads = source.MaxPhysicalIoReads,
            target.MinPhysicalIoReads = source.MinPhysicalIoReads,
            target.AvgCpuTimeMs = source.AvgCpuTimeMs,
            target.MaxCpuTimeMs = source.MaxCpuTimeMs,
            target.MinCpuTimeMs = source.MinCpuTimeMs,
            target.AvgClrTimeMs = source.AvgClrTimeMs,
            target.MaxClrTimeMs = source.MaxClrTimeMs,
            target.MinClrTimeMs = source.MinClrTimeMs,
            target.AvgElapsedTimeMs = source.AvgElapsedTimeMs,
            target.MaxElapsedTimeMs = source.MaxElapsedTimeMs,
            target.MinElapsedTimeMs = source.MinElapsedTimeMs,
            target.AvgMemoryUsedMb = source.AvgMemoryUsedMb,
            target.MaxMemoryUsedMb = source.MaxMemoryUsedMb,
            target.MinMemoryUsedMb = source.MinMemoryUsedMb,
            target.AvgRowCount = source.AvgRowCount,
            target.MaxRowCount = source.MaxRowCount,
            target.MinRowCount = source.MinRowCount
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            RuntimeStatsIntervalId, TenantName, ServerName, DatabaseName,
            QueryId, PlanId, ExecutionType, ExecutionTypeDesc,
            CountExecutions, AvgDurationMs, MaxDurationMs, MinDurationMs, StdevDurationMs,
            AvgLogicalIoReads, MaxLogicalIoReads, MinLogicalIoReads,
            AvgLogicalIoWrites, MaxLogicalIoWrites, MinLogicalIoWrites,
            AvgPhysicalIoReads, MaxPhysicalIoReads, MinPhysicalIoReads,
            AvgCpuTimeMs, MaxCpuTimeMs, MinCpuTimeMs,
            AvgClrTimeMs, MaxClrTimeMs, MinClrTimeMs,
            AvgElapsedTimeMs, MaxElapsedTimeMs, MinElapsedTimeMs,
            AvgMemoryUsedMb, MaxMemoryUsedMb, MinMemoryUsedMb,
            AvgRowCount, MaxRowCount, MinRowCount
        )
        VALUES (
            source.RuntimeStatsIntervalId, source.TenantName, source.ServerName, source.DatabaseName,
            source.QueryId, source.PlanId, source.ExecutionType, source.ExecutionTypeDesc,
            source.CountExecutions, source.AvgDurationMs, source.MaxDurationMs, source.MinDurationMs, source.StdevDurationMs,
            source.AvgLogicalIoReads, source.MaxLogicalIoReads, source.MinLogicalIoReads,
            source.AvgLogicalIoWrites, source.MaxLogicalIoWrites, source.MinLogicalIoWrites,
            source.AvgPhysicalIoReads, source.MaxPhysicalIoReads, source.MinPhysicalIoReads,
            source.AvgCpuTimeMs, source.MaxCpuTimeMs, source.MinCpuTimeMs,
            source.AvgClrTimeMs, source.MaxClrTimeMs, source.MinClrTimeMs,
            source.AvgElapsedTimeMs, source.MaxElapsedTimeMs, source.MinElapsedTimeMs,
            source.AvgMemoryUsedMb, source.MaxMemoryUsedMb, source.MinMemoryUsedMb,
            source.AvgRowCount, source.MaxRowCount, source.MinRowCount
        );

    SET @recordsInserted = @@ROWCOUNT

    -- Detect plan regressions: queries where the same query moved to a slower plan
    INSERT INTO qsh.PlanRegressions (
        TenantName, ServerName, DatabaseName, QueryId, 
        OldPlanId, NewPlanId, OldAvgDurationMs, NewAvgDurationMs, 
        DurationChangePercentage, DetectionDate
    )
    SELECT 
        rh.TenantName,
        rh.ServerName,
        rh.DatabaseName,
        rh.QueryId,
        rh.PlanId AS OldPlanId,
        rs.PlanId AS NewPlanId,
        AVG(rh.AvgDurationMs) AS OldAvgDurationMs,
        AVG(rs.AvgDurationMs) AS NewAvgDurationMs,
        ((AVG(rs.AvgDurationMs) - AVG(rh.AvgDurationMs)) / NULLIF(AVG(rh.AvgDurationMs), 0)) * 100 AS DurationChangePercentage,
        GETUTC()
    FROM qsh.QueryStoreRuntimeStats AS rh
    INNER JOIN qsh.QueryStoreRuntimeStats AS rs
        ON rh.QueryId = rs.QueryId
        AND rh.TenantName = rs.TenantName
        AND rh.ServerName = rs.ServerName
        AND rh.DatabaseName = rs.DatabaseName
    WHERE rh.TenantName = @TenantName 
      AND rh.ServerName = @ServerName
      AND rh.DatabaseName = @DatabaseName
      AND rh.PlanId <> rs.PlanId
      AND rh.RuntimeStatsIntervalId < rs.RuntimeStatsIntervalId
      AND ((AVG(rs.AvgDurationMs) - AVG(rh.AvgDurationMs)) / NULLIF(AVG(rh.AvgDurationMs), 0)) > 0.25 -- 25% increase = regression
      AND NOT EXISTS (
          SELECT 1 FROM qsh.PlanRegressions pr
          WHERE pr.QueryId = rh.QueryId
            AND pr.OldPlanId = rh.PlanId
            AND pr.NewPlanId = rs.PlanId
            AND DATEDIFF(DAY, pr.DetectionDate, GETUTC()) < 1
      )
    GROUP BY 
        rh.TenantName, rh.ServerName, rh.DatabaseName, rh.QueryId, 
        rh.PlanId, rs.PlanId

    SET @recordsRegression = @@ROWCOUNT
    
    -- Update IsRegression flag on new records if they match detected regressions
    UPDATE qsh.QueryStoreRuntimeStats
    SET IsRegression = 1
    WHERE EXISTS (
        SELECT 1 FROM qsh.PlanRegressions pr
        WHERE pr.QueryId = qsh.QueryStoreRuntimeStats.QueryId
          AND pr.NewPlanId = qsh.QueryStoreRuntimeStats.PlanId
          AND DATEDIFF(DAY, pr.DetectionDate, GETUTC()) < 1
    )
    AND TenantName = @TenantName
    AND ServerName = @ServerName
    AND DatabaseName = @DatabaseName

    COMMIT TRANSACTION

    -- Log results
    INSERT INTO qsh.ETLControl (
        TenantName, ServerName, DatabaseName,
        LastExtractTime, ExtractDurationSeconds,
        RecordsInserted, RecordsUpdated, ExtractStatus
    )
    VALUES (
        @TenantName, @ServerName, @DatabaseName,
        GETUTC(), 0,
        @recordsInserted, 0, 'SUCCESS'
    )

    SELECT @recordsInserted AS RecordsInserted, @recordsRegression AS RegressionsDetected

END
GO

-- ============================================================================
-- 2. MERGE for QueryStoreWaitStats
-- ============================================================================

IF OBJECT_ID('sp_MERGE_QueryStoreWaitStats', 'P') IS NOT NULL
    DROP PROCEDURE sp_MERGE_QueryStoreWaitStats
GO

CREATE PROCEDURE sp_MERGE_QueryStoreWaitStats
    @TenantName NVARCHAR(128),
    @ServerName NVARCHAR(128),
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE INTO qsh.QueryStoreWaitStats AS target
    USING (
        SELECT * FROM qsh.QueryStoreWaitStats_Staging
        WHERE TenantName = @TenantName 
          AND ServerName = @ServerName
          AND DatabaseName = @DatabaseName
    ) AS source
    ON (
        target.RuntimeStatsIntervalId = source.RuntimeStatsIntervalId
        AND target.TenantName = source.TenantName
        AND target.ServerName = source.ServerName
        AND target.DatabaseName = source.DatabaseName
        AND target.QueryId = source.QueryId
        AND target.PlanId = source.PlanId
        AND target.WaitCategory = source.WaitCategory
    )
    WHEN MATCHED THEN
        UPDATE SET
            target.TotalWaitTimeMs = source.TotalWaitTimeMs,
            target.AvgWaitTimeMs = source.AvgWaitTimeMs,
            target.MaxWaitTimeMs = source.MaxWaitTimeMs,
            target.CountWaits = source.CountWaits
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            RuntimeStatsIntervalId, TenantName, ServerName, DatabaseName,
            QueryId, PlanId, WaitCategory, WaitCategoryId,
            TotalWaitTimeMs, AvgWaitTimeMs, MaxWaitTimeMs,
            QueryWaitTimeCategory, CountWaits
        )
        VALUES (
            source.RuntimeStatsIntervalId, source.TenantName, source.ServerName, source.DatabaseName,
            source.QueryId, source.PlanId, source.WaitCategory, source.WaitCategoryId,
            source.TotalWaitTimeMs, source.AvgWaitTimeMs, source.MaxWaitTimeMs,
            source.QueryWaitTimeCategory, source.CountWaits
        );

END
GO

-- ============================================================================
-- 3. MERGE for Dimension Tables (Query, Text, Plan)
-- ============================================================================

IF OBJECT_ID('sp_MERGE_QueryDimensions', 'P') IS NOT NULL
    DROP PROCEDURE sp_MERGE_QueryDimensions
GO

CREATE PROCEDURE sp_MERGE_QueryDimensions
    @TenantName NVARCHAR(128),
    @ServerName NVARCHAR(128),
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    -- MERGE QueryStoreQuery
    MERGE INTO qsh.QueryStoreQuery AS target
    USING (
        SELECT * FROM qsh.QueryStoreQuery_Staging
        WHERE TenantName = @TenantName 
          AND ServerName = @ServerName
          AND DatabaseName = @DatabaseName
    ) AS source
    ON (
        target.QueryId = source.QueryId
        AND target.TenantName = source.TenantName
        AND target.ServerName = source.ServerName
        AND target.DatabaseName = source.DatabaseName
    )
    WHEN MATCHED THEN
        UPDATE SET
            target.CompilationCount = source.CompilationCount,
            target.AvgCompileCpuTimeMs = source.AvgCompileCpuTimeMs,
            target.MaxCompileCpuTimeMs = source.MaxCompileCpuTimeMs,
            target.AvgCompileMemoryMb = source.AvgCompileMemoryMb,
            target.MaxCompileMemoryMb = source.MaxCompileMemoryMb,
            target.CompilationEndTime = source.CompilationEndTime,
            target.LastCompilationBatchUTC = source.LastCompilationBatchUTC
    WHEN NOT MATCHED BY TARGET THEN
        INSERT VALUES (
            source.QueryId, source.TenantName, source.ServerName, source.DatabaseName,
            source.QueryTextId, source.ContextSettingsId, source.ObjectId,
            source.CompilationStartTime, source.CompilationEndTime,
            source.LastCompilationBatch, source.LastCompilationBatchUTC,
            source.CompilationCount, source.AvgCompileCpuTimeMs, source.MaxCompileCpuTimeMs,
            source.AvgCompileMemoryMb, source.MaxCompileMemoryMb,
            GETUTC()
        );

    -- MERGE QueryStoreQueryText
    MERGE INTO qsh.QueryStoreQueryText AS target
    USING (
        SELECT * FROM qsh.QueryStoreQueryText_Staging
        WHERE TenantName = @TenantName 
          AND ServerName = @ServerName
          AND DatabaseName = @DatabaseName
    ) AS source
    ON (
        target.QueryTextId = source.QueryTextId
        AND target.TenantName = source.TenantName
        AND target.ServerName = source.ServerName
        AND target.DatabaseName = source.DatabaseName
    )
    WHEN NOT MATCHED BY TARGET THEN
        INSERT VALUES (
            source.QueryTextId, source.TenantName, source.ServerName, source.DatabaseName,
            source.QueryTextContent, source.StatementType, source.QueryHash, source.QueryPlanHash,
            GETUTC()
        );

    -- MERGE QueryStorePlan
    MERGE INTO qsh.QueryStorePlan AS target
    USING (
        SELECT * FROM qsh.QueryStorePlan_Staging
        WHERE TenantName = @TenantName 
          AND ServerName = @ServerName
          AND DatabaseName = @DatabaseName
    ) AS source
    ON (
        target.PlanId = source.PlanId
        AND target.TenantName = source.TenantName
        AND target.ServerName = source.ServerName
        AND target.DatabaseName = source.DatabaseName
    )
    WHEN MATCHED THEN
        UPDATE SET
            target.LastExecutionTime = source.LastExecutionTime
    WHEN NOT MATCHED BY TARGET THEN
        INSERT VALUES (
            source.PlanId, source.TenantName, source.ServerName, source.DatabaseName,
            source.QueryId, source.EngineVersion, source.CompatibilityLevel,
            source.QueryPlanHash, source.QueryHash, source.PlanHandle,
            source.CreationTime, source.LastExecutionTime,
            source.QueryPlanCompressed, source.QueryPlanText,
            source.IsOnlineIndexPlan, source.IsParallelizable,
            GETUTC()
        );

    -- MERGE RuntimeStatsInterval
    MERGE INTO qsh.RuntimeStatsInterval AS target
    USING (
        SELECT * FROM qsh.RuntimeStatsInterval_Staging
        WHERE TenantName = @TenantName 
          AND ServerName = @ServerName
    ) AS source
    ON (
        target.RuntimeStatsIntervalId = source.RuntimeStatsIntervalId
        AND target.TenantName = source.TenantName
        AND target.ServerName = source.ServerName
    )
    WHEN NOT MATCHED BY TARGET THEN
        INSERT VALUES (
            source.RuntimeStatsIntervalId, source.TenantName, source.ServerName,
            source.IntervalStartTime, source.IntervalEndTime, source.IntervalDurationMinutes,
            source.CapturedDate, source.CapturedTime,
            GETUTC()
        );

END
GO

PRINT 'MERGE and SCD Type 2 Procedures Created Successfully'
GO
