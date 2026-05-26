/*
================================================================================
Query Store Historical Data Warehouse - DDL Script
Purpose: Creates the centralized schema for multi-tenant Query Store data
Target Database: Azure SQL Database or Fabric SQL Database
Author: GitHub Copilot
Date: 2026-05-26
================================================================================
*/

-- Set database context (execute this manually with your target database name)
-- USE [HistoricalQueryStore]
-- GO

-- Create schema for Query Store tables
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'qsh')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA qsh'
    PRINT 'Schema [qsh] created successfully'
END
GO

-- ============================================================================
-- DIMENSION TABLES
-- ============================================================================

-- 1. RuntimeStatsInterval - Time dimension for aggregation intervals
IF OBJECT_ID('qsh.RuntimeStatsInterval', 'U') IS NOT NULL
    DROP TABLE qsh.RuntimeStatsInterval
GO

CREATE TABLE qsh.RuntimeStatsInterval (
    RuntimeStatsIntervalId INT NOT NULL,
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    IntervalStartTime DATETIME2(7) NOT NULL,
    IntervalEndTime DATETIME2(7) NOT NULL,
    IntervalDurationMinutes INT NOT NULL,
    CapturedDate DATE NOT NULL,
    CapturedTime TIME(7) NOT NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT PK_RuntimeStatsInterval PRIMARY KEY CLUSTERED (RuntimeStatsIntervalId, TenantName, ServerName)
)
GO

-- 2. QueryStoreQuery - Query definitions
IF OBJECT_ID('qsh.QueryStoreQuery', 'U') IS NOT NULL
    DROP TABLE qsh.QueryStoreQuery
GO

CREATE TABLE qsh.QueryStoreQuery (
    QueryId BIGINT NOT NULL,
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    QueryTextId BIGINT NOT NULL,
    ContextSettingsId BIGINT NOT NULL,
    ObjectId BIGINT NULL,
    CompilationStartTime DATETIME2(7) NOT NULL,
    CompilationEndTime DATETIME2(7) NOT NULL,
    LastCompilationBatch BIGINT NOT NULL,
    LastCompilationBatchUTC DATETIME2(7) NOT NULL,
    CompilationCount BIGINT NOT NULL,
    AvgCompileCpuTimeMs FLOAT NOT NULL,
    MaxCompileCpuTimeMs FLOAT NOT NULL,
    AvgCompileMemoryMb FLOAT NOT NULL,
    MaxCompileMemoryMb FLOAT NOT NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT PK_QueryStoreQuery PRIMARY KEY CLUSTERED (QueryId, TenantName, ServerName, DatabaseName)
)
GO

-- 3. QueryStoreQueryText - Actual T-SQL text
IF OBJECT_ID('qsh.QueryStoreQueryText', 'U') IS NOT NULL
    DROP TABLE qsh.QueryStoreQueryText
GO

CREATE TABLE qsh.QueryStoreQueryText (
    QueryTextId BIGINT NOT NULL,
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    QueryTextContent NVARCHAR(MAX) NOT NULL,
    StatementType NVARCHAR(128) NULL,
    QueryHash BINARY(8) NULL,
    QueryPlanHash BINARY(8) NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT PK_QueryStoreQueryText PRIMARY KEY CLUSTERED (QueryTextId, TenantName, ServerName, DatabaseName)
)
GO

-- 4. QueryStorePlan - Execution plans (XML)
IF OBJECT_ID('qsh.QueryStorePlan', 'U') IS NOT NULL
    DROP TABLE qsh.QueryStorePlan
GO

CREATE TABLE qsh.QueryStorePlan (
    PlanId BIGINT NOT NULL,
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    QueryId BIGINT NOT NULL,
    EngineVersion NVARCHAR(32) NOT NULL,
    CompatibilityLevel INT NOT NULL,
    QueryPlanHash BINARY(8) NULL,
    QueryHash BINARY(8) NULL,
    PlanHandle VARBINARY(64) NULL,
    CreationTime DATETIME2(7) NOT NULL,
    LastExecutionTime DATETIME2(7) NOT NULL,
    QueryPlanCompressed VARBINARY(MAX) NULL,
    QueryPlanText XML NULL,
    IsOnlineIndexPlan BIT NULL,
    IsParallelizable BIT NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT PK_QueryStorePlan PRIMARY KEY CLUSTERED (PlanId, TenantName, ServerName, DatabaseName)
)
GO

-- ============================================================================
-- FACT TABLES
-- ============================================================================

-- 5. QueryStoreRuntimeStats - Execution statistics per interval
IF OBJECT_ID('qsh.QueryStoreRuntimeStats', 'U') IS NOT NULL
    DROP TABLE qsh.QueryStoreRuntimeStats
GO

CREATE TABLE qsh.QueryStoreRuntimeStats (
    RuntimeStatsId BIGINT NOT NULL IDENTITY(1,1),
    RuntimeStatsIntervalId INT NOT NULL,
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    QueryId BIGINT NOT NULL,
    PlanId BIGINT NOT NULL,
    ExecutionType INT NOT NULL, -- 0=Regular, 1=Aborted, 2=Exception
    ExecutionTypeDesc NVARCHAR(128) NOT NULL,
    CountExecutions BIGINT NOT NULL,
    AvgDurationMs FLOAT NOT NULL,
    MaxDurationMs FLOAT NOT NULL,
    MinDurationMs FLOAT NOT NULL,
    StdevDurationMs FLOAT NULL,
    AvgLogicalIoReads BIGINT NOT NULL,
    MaxLogicalIoReads BIGINT NOT NULL,
    MinLogicalIoReads BIGINT NOT NULL,
    AvgLogicalIoWrites BIGINT NOT NULL,
    MaxLogicalIoWrites BIGINT NOT NULL,
    MinLogicalIoWrites BIGINT NOT NULL,
    AvgPhysicalIoReads BIGINT NOT NULL,
    MaxPhysicalIoReads BIGINT NOT NULL,
    MinPhysicalIoReads BIGINT NOT NULL,
    AvgCpuTimeMs FLOAT NOT NULL,
    MaxCpuTimeMs FLOAT NOT NULL,
    MinCpuTimeMs FLOAT NOT NULL,
    AvgClrTimeMs FLOAT NOT NULL,
    MaxClrTimeMs FLOAT NOT NULL,
    MinClrTimeMs FLOAT NOT NULL,
    AvgElapsedTimeMs FLOAT NOT NULL,
    MaxElapsedTimeMs FLOAT NOT NULL,
    MinElapsedTimeMs FLOAT NOT NULL,
    AvgMemoryUsedMb FLOAT NOT NULL,
    MaxMemoryUsedMb FLOAT NOT NULL,
    MinMemoryUsedMb FLOAT NOT NULL,
    AvgRowCount FLOAT NOT NULL,
    MaxRowCount BIGINT NOT NULL,
    MinRowCount BIGINT NOT NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    IsRegression BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_QueryStoreRuntimeStats PRIMARY KEY CLUSTERED (RuntimeStatsId, RuntimeStatsIntervalId, TenantName, ServerName)
)
GO

-- Nonclustered index for query lookups
CREATE NONCLUSTERED INDEX IX_RuntimeStats_Query ON qsh.QueryStoreRuntimeStats 
    (TenantName, ServerName, DatabaseName, QueryId, PlanId)
GO

-- Nonclustered index for performance analysis
CREATE NONCLUSTERED INDEX IX_RuntimeStats_Performance ON qsh.QueryStoreRuntimeStats 
    (TenantName, ServerName, AvgDurationMs DESC, MaxDurationMs DESC)
INCLUDE (QueryId, PlanId, CountExecutions)
GO

-- 6. QueryStoreWaitStats - Wait statistics by category
IF OBJECT_ID('qsh.QueryStoreWaitStats', 'U') IS NOT NULL
    DROP TABLE qsh.QueryStoreWaitStats
GO

CREATE TABLE qsh.QueryStoreWaitStats (
    WaitStatsId BIGINT NOT NULL IDENTITY(1,1),
    RuntimeStatsIntervalId INT NOT NULL,
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    QueryId BIGINT NOT NULL,
    PlanId BIGINT NOT NULL,
    WaitCategory NVARCHAR(128) NOT NULL,
    WaitCategoryId INT NOT NULL,
    TotalWaitTimeMs BIGINT NOT NULL,
    AvgWaitTimeMs FLOAT NOT NULL,
    MaxWaitTimeMs BIGINT NOT NULL,
    QueryWaitTimeCategory INT NOT NULL, -- Execution vs CLR vs IO
    CountWaits BIGINT NOT NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT PK_QueryStoreWaitStats PRIMARY KEY CLUSTERED (WaitStatsId, RuntimeStatsIntervalId, TenantName, ServerName)
)
GO

-- Nonclustered index for wait category analysis
CREATE NONCLUSTERED INDEX IX_WaitStats_Category ON qsh.QueryStoreWaitStats 
    (TenantName, ServerName, WaitCategory, TotalWaitTimeMs DESC)
INCLUDE (CountWaits, AvgWaitTimeMs)
GO

-- ============================================================================
-- CONTROL TABLES
-- ============================================================================

-- 7. ETL Control - Track extraction status
IF OBJECT_ID('qsh.ETLControl', 'U') IS NOT NULL
    DROP TABLE qsh.ETLControl
GO

CREATE TABLE qsh.ETLControl (
    ETLControlId INT NOT NULL IDENTITY(1,1),
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    LastExtractTime DATETIME2(7) NOT NULL,
    ExtractDurationSeconds INT NOT NULL,
    RecordsInserted BIGINT NOT NULL,
    RecordsUpdated BIGINT NOT NULL,
    ExtractStatus NVARCHAR(50) NOT NULL, -- 'SUCCESS', 'FAILED', 'IN_PROGRESS'
    ErrorMessage NVARCHAR(MAX) NULL,
    LoadDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT PK_ETLControl PRIMARY KEY CLUSTERED (ETLControlId)
)
GO

-- 8. PlanRegression Tracking
IF OBJECT_ID('qsh.PlanRegressions', 'U') IS NOT NULL
    DROP TABLE qsh.PlanRegressions
GO

CREATE TABLE qsh.PlanRegressions (
    RegressionId BIGINT NOT NULL IDENTITY(1,1),
    TenantName NVARCHAR(128) NOT NULL,
    ServerName NVARCHAR(128) NOT NULL,
    DatabaseName NVARCHAR(128) NOT NULL,
    QueryId BIGINT NOT NULL,
    OldPlanId BIGINT NOT NULL,
    NewPlanId BIGINT NOT NULL,
    OldAvgDurationMs FLOAT NOT NULL,
    NewAvgDurationMs FLOAT NOT NULL,
    DurationChangePercentage FLOAT NOT NULL,
    DetectionDate DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    IsInvestigated BIT NOT NULL DEFAULT 0,
    Notes NVARCHAR(MAX) NULL,
    CONSTRAINT PK_PlanRegressions PRIMARY KEY CLUSTERED (RegressionId)
)
GO

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Additional support indexes for common queries
CREATE NONCLUSTERED INDEX IX_Query_ContextSettings 
ON qsh.QueryStoreQuery (ContextSettingsId)
INCLUDE (QueryId, ObjectId)
GO

CREATE NONCLUSTERED INDEX IX_Plan_Hash 
ON qsh.QueryStorePlan (QueryHash, QueryPlanHash)
INCLUDE (PlanId, CreationTime)
GO

-- ============================================================================
-- METADATA & DOCUMENTATION
-- ============================================================================

PRINT '==============================================='
PRINT 'Query Store Historical Data Warehouse Created'
PRINT '==============================================='
PRINT 'Schema: qsh'
PRINT 'Tables Created: 8'
PRINT 'Clustered Indexes: 8'
PRINT 'Nonclustered Indexes: 5'
PRINT ''
PRINT 'Tables:'
PRINT '  1. RuntimeStatsInterval (Control)'
PRINT '  2. QueryStoreQuery (Dimension)'
PRINT '  3. QueryStoreQueryText (Dimension)'
PRINT '  4. QueryStorePlan (Dimension)'
PRINT '  5. QueryStoreRuntimeStats (Fact)'
PRINT '  6. QueryStoreWaitStats (Fact)'
PRINT '  7. ETLControl (Control)'
PRINT '  8. PlanRegressions (Analysis)'
PRINT '==============================================='
GO
