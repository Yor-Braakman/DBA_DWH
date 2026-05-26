# Query Store Historical Data Warehouse - Complete Implementation Guide

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Deployment Instructions](#deployment-instructions)
3. [ETL Configuration](#etl-configuration)
4. [Power BI Setup](#power-bi-setup)
5. [Maintenance & Operations](#maintenance--operations)
6. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Purpose
This solution centralizes Query Store data from multiple SQL Server instances into a single Azure SQL Database or Fabric SQL Database, enabling:
- **Historical analysis** of query performance trends
- **Plan regression detection** across versions
- **Multi-tenant support** for managed service providers
- **Centralized DBA dashboarding** via Power BI
- **Proactive performance monitoring**

### Data Flow
```
Source SQL Servers
        ↓
  Query Store Data
  (via PowerShell/dbatools)
        ↓
ETL Process
(MERGE with SCD Type 2)
        ↓
Historical Query Store
(Central Repository)
        ↓
Data Modeling Views
(Dimensions & Facts)
        ↓
Power BI Dashboard
(DBA Reporting)
```

### Schema Design

#### Multi-Tenancy Support
Every table includes three context columns:
- **TenantName**: Logical grouping (customer name, environment, etc.)
- **ServerName**: Source SQL Server instance name
- **DatabaseName**: Source database name

#### Primary Tables

**Dimensions:**
- `qsh.QueryStoreQuery`: Query metadata and compilation statistics
- `qsh.QueryStoreQueryText`: T-SQL query text content
- `qsh.QueryStorePlan`: Execution plan XML and metadata
- `qsh.RuntimeStatsInterval`: Time interval definitions

**Facts:**
- `qsh.QueryStoreRuntimeStats`: Aggregated execution metrics per interval
- `qsh.QueryStoreWaitStats`: Wait statistics by category and interval

**Control:**
- `qsh.ETLControl`: ETL job tracking and logging
- `qsh.PlanRegressions`: Detected plan regressions with SCD Type 2

---

## Deployment Instructions

### Step 1: Create the Target Database

```sql
-- Azure SQL Database
CREATE DATABASE HistoricalQueryStore 
    (EDITION = 'Standard', SERVICE_OBJECTIVE = 'S1')

-- OR Fabric SQL Database
CREATE DATABASE HistoricalQueryStore
    WITH AUTOGROW_ALL_FILES = ON
```

### Step 2: Execute DDL Script

```sql
-- In HistoricalQueryStore database
-- Execute: 01-DDL/01_Create_HistoricalQueryStore_Schema.sql

USE HistoricalQueryStore
GO

-- Run the entire script - it will create:
-- - Schema: qsh
-- - 8 tables with clustered indexes
-- - 5 nonclustered indexes
-- - Appropriate constraints and relationships
```

### Step 3: Create Data Modeling Views

```sql
-- In HistoricalQueryStore database
-- Execute: 03-DataModeling/01_Create_DataModeling_Views.sql

-- Creates:
-- - 4 Dimension views (DimQuery, DimPlan, DimInterval, DimWaitCategory)
-- - 4 Fact views with aggregations
-- - Pre-aggregated views for dashboard performance
```

### Step 4: Deploy Maintenance Procedures

```sql
-- In HistoricalQueryStore database
-- Execute: 04-Maintenance/01_Maintenance_Procedures.sql

-- Creates stored procedures:
-- - sp_CleanupHistoricalData: Data retention policy
-- - sp_MaintainIndexes: Index reorganization/rebuild
-- - sp_UpdateStatistics: Statistics refresh
-- - sp_AnalyzeStorageUsage: Storage reporting
```

### Step 5: Deploy ETL Logic

```sql
-- In HistoricalQueryStore database
-- Execute: 02-ETL/02_MERGE_SCD_Type2_Logic.sql

-- Creates stored procedures:
-- - sp_MERGE_QueryStoreRuntimeStats: SCD Type 2 with regression detection
-- - sp_MERGE_QueryStoreWaitStats: Wait statistics merge
-- - sp_MERGE_QueryDimensions: Dimension table upserts
```

---

## ETL Configuration

### PowerShell Prerequisites

1. **Install Required Modules:**
   ```powershell
   Install-Module dbatools -Force
   Install-Module SqlServer -Force
   ```

2. **Verify Installation:**
   ```powershell
   Get-Module -ListAvailable dbatools, SqlServer
   ```

### Configuration File (SourceServers.json)

Place this file in the same directory as the PowerShell script:

```json
{
    "servers": [
        {
            "serverName": "sql-server-01.corp.local",
            "tenantName": "CompanyA",
            "databases": ["Database1", "Database2"],
            "useWindowsAuth": true
        },
        {
            "serverName": "sql-server-02.database.windows.net",
            "tenantName": "CompanyB",
            "databases": ["SalesDB", "AnalyticsDB"],
            "useWindowsAuth": false,
            "username": "dbuser@contoso.com",
            "password": "SecurePassword123!"
        },
        {
            "serverName": "managed-instance.region.database.windows.net",
            "tenantName": "CompanyC",
            "databases": ["ProdDB"],
            "useWindowsAuth": false,
            "username": "migrationadmin",
            "password": "ManagedInstancePassword!"
        }
    ]
}
```

### Running the ETL Script

**Basic Execution (hourly interval):**
```powershell
cd C:\Source\TGQS\02-ETL

# For Azure SQL with SQL authentication
.\01_QueryStore_ETL_PowerShell.ps1 `
    -SourceServersFile "SourceServers.json" `
    -TargetServer "target-server.database.windows.net" `
    -TargetDatabase "HistoricalQueryStore" `
    -TargetUsername "adminuser@contoso.com" `
    -TargetPassword "AdminPassword123!"
```

**Advanced Options:**
```powershell
# Windows Authentication to on-premises SQL Server
.\01_QueryStore_ETL_PowerShell.ps1 `
    -SourceServersFile "SourceServers.json" `
    -TargetServer "on-prem-server\SQLINSTANCE" `
    -TargetDatabase "HistoricalQueryStore" `
    -UseWindowsAuthentication `
    -BulkCopyTimeout 600
```

### Schedule with Windows Task Scheduler

1. **Create Task:**
   ```
   - Trigger: Daily, 03:00 AM
   - Action: PowerShell.exe
   - Arguments: -NoProfile -ExecutionPolicy Bypass -File "C:\Source\TGQS\02-ETL\01_QueryStore_ETL_PowerShell.ps1"
   ```

2. **Or use cron-like scheduling:**
   ```powershell
   # Create scheduled task via PowerShell
   $trigger = New-ScheduledTaskTrigger -Daily -At 03:00
   $action = New-ScheduledTaskAction -Execute "powershell.exe" `
       -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Source\TGQS\02-ETL\01_QueryStore_ETL_PowerShell.ps1"
   Register-ScheduledTask -TaskName "QueryStore-ETL-Daily" -Trigger $trigger -Action $action
   ```

### ETL Data Flow Diagram

```
PowerShell Script
  │
  ├─→ Flush Query Store (sp_query_store_flush_db)
  │
  ├─→ Extract sys.query_store_*
  │   ├─ query_store_query
  │   ├─ query_store_query_text
  │   ├─ query_store_plan
  │   ├─ query_store_runtime_stats
  │   ├─ query_store_wait_stats
  │   └─ query_store_runtime_stats_interval
  │
  ├─→ Add Context (TenantName, ServerName, DatabaseName)
  │
  ├─→ Bulk Load to Staging Tables
  │
  └─→ MERGE to Production Tables
      ├─ Dimension updates
      ├─ Fact inserts/updates
      └─ Regression detection
```

---

## Power BI Setup

### Data Source Connection

1. **Open Power BI Desktop**
2. **Get Data → SQL Server**
3. **Connection Details:**
   - Server: `target-server.database.windows.net` (or on-prem server\instance)
   - Database: `HistoricalQueryStore`
   - Data Connectivity Mode: `Import` (recommended for historical data)

### Query Selection

Select these views for your model:
- `qsh.DimQuery`
- `qsh.DimPlan`
- `qsh.DimInterval`
- `qsh.DimWaitCategory`
- `qsh.FactRuntimeStats`
- `qsh.FactWaitStats`
- `qsh.FactTopQueries`
- `qsh.FactWaitSummary`

### Data Model Relationships

Create relationships in Power BI:

| From View | To View | Cardinality |
|-----------|---------|-------------|
| DimQuery | FactRuntimeStats | 1:M (QueryDimKey) |
| DimPlan | FactRuntimeStats | 1:M (PlanDimKey) |
| DimInterval | FactRuntimeStats | 1:M (RuntimeStatsIntervalId) |
| DimWaitCategory | FactWaitStats | 1:M (WaitCategoryId) |

### Recommended Measures

Add all measures from `05-PowerBI/01_DAX_Measures.dax`:
- Performance Indicators
- Comparison Metrics
- Wait Analysis
- Regression Detection
- Efficiency Metrics

### Sample Dashboard Layout

**Page 1: Executive Overview**
- KPI cards: Avg Duration, Total Executions, Max CPU Time
- Trend chart: Duration over time
- Top 10 queries by duration

**Page 2: Performance Analysis**
- Query details table (filterable)
- Plan history per query
- Performance metrics comparison

**Page 3: Wait Analysis**
- Wait category breakdown (pie chart)
- CPU/Memory/IO wait trends
- Top wait-causing queries

**Page 4: Regression Alerts**
- Regression timeline
- Affected queries list
- Plan comparison (before/after)

**Page 5: Multi-Tenant Comparison**
- Server/tenant slicers
- Comparative metrics by tenant
- Resource consumption ranking

---

## Maintenance & Operations

### Daily Maintenance (03:00 AM)

```sql
-- Run these stored procedures daily
EXEC qsh.sp_CleanupHistoricalData @RetentionDays = 90, @DryRun = 0
EXEC qsh.sp_MaintainIndexes @FragmentationThreshold = 10.0
EXEC qsh.sp_UpdateStatistics
```

### Weekly Reporting (Sunday 08:00 AM)

```sql
-- Storage analysis and performance report
EXEC qsh.sp_AnalyzeStorageUsage

-- Refresh Power BI dataset
-- (Configure in Power BI Service Settings)
```

### Retention Policy

- **Query Store data**: 90 days (configurable)
- **Plan changes**: 30 days (older regressions archived)
- **Wait statistics**: 90 days
- **ETL logs**: 60 days

### Monitoring Alerts

Set up alerts in your monitoring system:

1. **ETL Failures**
   - Alert if `qsh.ETLControl.ExtractStatus` = 'FAILED'

2. **Plan Regressions**
   - Alert if new regressions detected: `SELECT COUNT(*) FROM qsh.PlanRegressions WHERE DetectionDate > DATEADD(HOUR, -1, GETUTC())`

3. **Storage Thresholds**
   - Alert if database size exceeds 100 GB

4. **Missing Data**
   - Alert if no data loaded in last 4 hours

---

## Troubleshooting

### Issue: PowerShell Script Fails with "Module Not Found"

**Solution:**
```powershell
# Install missing modules
Install-Module dbatools -Repository PSGallery -Force
Install-Module SqlServer -Repository PSGallery -Force

# Verify
Get-Module -ListAvailable | Where-Object {$_.Name -match "dbatools|SqlServer"}
```

### Issue: "Connection Timeout" to Source Servers

**Solution:**
- Verify network connectivity: `Test-NetConnection -ComputerName source-server -Port 1433`
- Check SQL Server authentication:
  ```sql
  -- On source server
  SELECT name, state_desc FROM sys.databases WHERE name = 'YourDatabase'
  ```
- Verify firewall rules (especially for Azure SQL and Managed Instances)

### Issue: ETL Takes Too Long (>30 minutes)

**Optimization:**
1. Increase `@BulkCopyTimeout` parameter
2. Run extract during off-peak hours
3. Consider partitioning by tenant/server
4. Enable parallelization in PowerShell

```powershell
# Parallel processing example
$servers | ForEach-Object -Parallel {
    # Extract logic here
}
```

### Issue: High CPU on Target Database During ETL

**Solution:**
```sql
-- Reduce data volume
-- Modify ETL to extract last 7 days instead of 30

-- Add resource throttling
-- ALTER WORKLOAD GROUP default WITH (request_max_cpu_time_sec = 60)
```

### Issue: Plan Regression Not Detected

**Verification:**
```sql
-- Check if data exists
SELECT COUNT(*) FROM qsh.QueryStoreRuntimeStats 
WHERE IsRegression = 1

-- Manual regression detection
SELECT 
    QueryId, PlanId, AVG(AvgDurationMs) AS AvgDuration
FROM qsh.QueryStoreRuntimeStats
GROUP BY QueryId, PlanId
HAVING COUNT(DISTINCT RuntimeStatsIntervalId) > 10
```

### Issue: "Permission Denied" in Power BI

**Solution:**
1. Verify user has SELECT permissions on schema:
   ```sql
   GRANT SELECT ON SCHEMA::qsh TO [domain\user]
   ```

2. Enable row-level security if needed:
   ```sql
   CREATE FUNCTION qsh.fn_securitypredicate(@TenantName AS NVARCHAR(128))
   RETURNS TABLE WITH SCHEMABINDING
   AS RETURN SELECT 1 AS fn_securitypredicate
   WHERE @TenantName = USER_NAME()
   ```

---

## Support & Additional Resources

- **Query Store Documentation**: [Microsoft Docs](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)
- **dbatools Documentation**: [dbatools.io](https://dbatools.io)
- **Power BI DAX Reference**: [Power BI Docs](https://learn.microsoft.com/en-us/dax)

## Version History

- **v1.0** (2026-05-26): Initial release with core functionality
- Multi-tenant support with 3-column context
- 8 core tables with SCD Type 2 plan tracking
- 40+ DAX measures for analysis
- Complete maintenance framework
