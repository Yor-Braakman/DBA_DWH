# SQL Database Project - Migration & Implementation Guide

## ✅ Project Structure Complete

Your SQL Database Project is now properly organized with **30 objects**:

### 📁 Directory Structure
```
c:\Source\TGQS\DBA_DWH/
├── DBA_DWH.sqlproj              ← Main project file (all objects listed)
├── README.md                     ← Project documentation
│
├── Schema/ (1 file)
│   └── qsh.sql
│
├── Tables/ (8 files)
│   ├── RuntimeStatsInterval.sql
│   ├── QueryStoreQuery.sql
│   ├── QueryStoreQueryText.sql
│   ├── QueryStorePlan.sql
│   ├── QueryStoreRuntimeStats.sql
│   ├── QueryStoreWaitStats.sql
│   ├── ETLControl.sql
│   └── PlanRegressions.sql
│
├── Views/ (8 files)
│   ├── DimQuery.sql
│   ├── DimPlan.sql
│   ├── DimInterval.sql
│   ├── DimWaitCategory.sql
│   ├── FactRuntimeStats.sql
│   ├── FactWaitStats.sql
│   ├── FactTopQueries.sql
│   └── FactWaitSummary.sql
│
└── Procedures/ (7 files)
    ├── sp_MERGE_QueryStoreRuntimeStats.sql
    ├── sp_MERGE_QueryStoreWaitStats.sql
    ├── sp_MERGE_QueryDimensions.sql
    ├── sp_CleanupHistoricalData.sql
    ├── sp_MaintainIndexes.sql
    ├── sp_UpdateStatistics.sql
    └── sp_AnalyzeStorageUsage.sql
```

---

## 🔑 Key Improvements - Primary Key Redesign

### BEFORE (Original Design)
```sql
-- Scattered tenant context
CREATE TABLE qsh.QueryStoreRuntimeStats (
    RuntimeStatsId BIGINT PRIMARY KEY,
    TenantName NVARCHAR(128),
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    QueryId BIGINT,
    ...
)
-- ⚠️ Clustering not optimized for multi-tenant queries
```

### AFTER (New Optimized Design)
```sql
-- Multi-tenant columns FIRST
CREATE TABLE qsh.QueryStoreRuntimeStats (
    RuntimeStatsId BIGINT,
    TenantName NVARCHAR(128),
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    RuntimeStatsIntervalId INT,
    QueryId BIGINT,
    ...
    CONSTRAINT PK_QueryStoreRuntimeStats PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [RuntimeStatsId] ASC, [RuntimeStatsIntervalId] ASC)
)
-- ✅ Optimized for tenant/server/database filtering
```

### Benefits

| Aspect | Improvement |
|--------|------------|
| **Filtering** | Filter by (Tenant, Server, Database) → Immediate index seek |
| **Partitioning** | Can partition by TenantName → Easier multi-tenant maintenance |
| **Scalability** | Reduces key size for tenant-specific subsets |
| **Management** | Cleanup/maintenance per tenant becomes efficient |
| **Query Performance** | Queries filtering by tenant benefit from leading PK columns |

### All Table PKs Updated

| Table | New PK Structure |
|-------|------------------|
| RuntimeStatsInterval | (TenantName, ServerName, RuntimeStatsIntervalId) |
| QueryStoreQuery | (TenantName, ServerName, DatabaseName, QueryId) |
| QueryStoreQueryText | (TenantName, ServerName, DatabaseName, QueryTextId) |
| QueryStorePlan | (TenantName, ServerName, DatabaseName, PlanId) |
| QueryStoreRuntimeStats | (TenantName, ServerName, DatabaseName, RuntimeStatsId, RuntimeStatsIntervalId) |
| QueryStoreWaitStats | (TenantName, ServerName, DatabaseName, WaitStatsId, RuntimeStatsIntervalId) |
| ETLControl | (TenantName, ServerName, DatabaseName, ETLControlId) |
| PlanRegressions | (TenantName, ServerName, DatabaseName, RegressionId) |

---

## 🚀 Implementation Steps

### Step 1: Open Project in Visual Studio or SSDT
```
File → Open → Project/Solution
Navigate to: c:\Source\TGQS\DBA_DWH\DBA_DWH.sqlproj
```

### Step 2: Build Project (Validates Syntax)
```
Build → Build Solution
```
✅ Should succeed with "0 errors"

### Step 3: Connect to Target Database
```
Project → Connections → New SQL Server Connection
- Server: (your Azure SQL or on-premises server)
- Database: (leave blank or select HistoricalQueryStore)
```

### Step 4: Publish Project
```
Project → Publish
- Select Target Connection
- Click Preview to see changes
- Click Publish to deploy
```

### Step 5: Verify Deployment
```sql
-- Check schema exists
SELECT name FROM sys.schemas WHERE name = 'qsh'

-- Check tables
SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('qsh')

-- Check views
SELECT name FROM sys.views WHERE schema_id = SCHEMA_ID('qsh')

-- Check procedures
SELECT name FROM sys.procedures WHERE schema_id = SCHEMA_ID('qsh')
```

---

## 🔧 Updating ETL Scripts

Your PowerShell ETL script needs minor updates for new PK structure:

### Update Bulk Insert Statement
```powershell
# OLD: RuntimeStatsId as first column
INSERT INTO qsh.QueryStoreRuntimeStats (
    RuntimeStatsId, TenantName, ServerName, DatabaseName, ...

# NEW: TenantName, ServerName, DatabaseName first
INSERT INTO qsh.QueryStoreRuntimeStats (
    TenantName, ServerName, DatabaseName, RuntimeStatsId, ...
```

### Update Staging Table Order
When loading from PowerShell, column order matters for bulk insert:
```powershell
$sqlBulkCopy.ColumnMappings.Add("TenantName", "TenantName")
$sqlBulkCopy.ColumnMappings.Add("ServerName", "ServerName")
$sqlBulkCopy.ColumnMappings.Add("DatabaseName", "DatabaseName")
$sqlBulkCopy.ColumnMappings.Add("RuntimeStatsId", "RuntimeStatsId")
# ... rest of columns
```

---

## 📊 Deployment Architecture

### Development Environment
```
SQL Database Project (SSDT)
    ↓ [Local Development Database]
    ↓ [Preview changes]
```

### Production Deployment Options

#### Option A: Direct Publish (Recommended for small teams)
```
DBA_DWH.sqlproj → [Publish] → Azure SQL / SQL Server
```

#### Option B: DACPAC Generation (Recommended for CI/CD)
```
Build Project → DBA_DWH.dacpac
    ↓
SqlPackage /Action:Publish /SourceFile:DBA_DWH.dacpac ...
    ↓
Azure SQL / SQL Server
```

#### Option C: Script Generation (Review before deploy)
```
Project → Publish → [Generate Script] → Deploy.sql
    ↓
Review SQL script
    ↓
Execute in SSMS
```

---

## ✨ New Features with SQLPROJ

### Pre-Deployment Scripts
```xml
<!-- Pre-deployment.sql: Backup before update -->
<PreDeploy Include="PreDeploy\Backup.sql" />
```

### Post-Deployment Scripts
```xml
<!-- Post-deployment.sql: Data migration, seed data -->
<PostDeploy Include="PostDeploy\DataMigration.sql" />
```

### Version Control
```
Git Status:
- DBA_DWH.sqlproj ← Track changes
- Schema/
- Tables/
- Views/
- Procedures/

.gitignore:
- bin/
- obj/
- *.dacpac
- *.user
```

### Continuous Integration / Deployment
```yaml
# Example: Azure DevOps Pipeline
- task: SQLAzureDacpacTask@1
  inputs:
    azureSubscription: 'MyAzureConnection'
    AuthenticationType: 'servicePrincipal'
    ServerName: 'myserver.database.windows.net'
    DatabaseName: 'HistoricalQueryStore'
    DacpacFile: '$(Build.ArtifactStagingDirectory)\DBA_DWH.dacpac'
```

---

## 🎯 Tenant-Aware Queries

With new PK structure, all queries are optimized:

### Query by Tenant
```sql
-- Fast: Seeks into clustered index immediately
SELECT * 
FROM qsh.QueryStoreRuntimeStats
WHERE TenantName = 'Tenant_A'
AND ServerName = 'Server_1'
AND QueryId = 123
```

### Cleanup by Tenant
```sql
-- Efficient: Targets specific tenant partition
EXEC qsh.sp_CleanupHistoricalData 
    @TenantName = 'Tenant_A',
    @RetentionDays = 90,
    @DryRun = 0
```

### Multi-Tenant Comparison
```sql
-- Easily compare across tenants
SELECT 
    TenantName,
    ServerName,
    AVG(AvgDurationMs) AS AvgQueryDuration
FROM qsh.FactRuntimeStats
GROUP BY TenantName, ServerName
```

---

## 🔍 Validation Checklist

After Deployment, Verify:

- [ ] Schema `qsh` exists
  ```sql
  SELECT * FROM sys.schemas WHERE name = 'qsh'
  ```

- [ ] All 8 tables created with correct PKs
  ```sql
  SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('qsh')
  ```

- [ ] All 8 views exist
  ```sql
  SELECT name FROM sys.views WHERE schema_id = SCHEMA_ID('qsh')
  ```

- [ ] All 7 procedures exist
  ```sql
  SELECT name FROM sys.procedures WHERE schema_id = SCHEMA_ID('qsh')
  ```

- [ ] PK columns in correct order (Tenant, Server, Database first)
  ```sql
  EXEC sp_helpindex 'qsh.QueryStoreRuntimeStats'
  ```

- [ ] Indexes created successfully
  ```sql
  SELECT name FROM sys.indexes 
  WHERE object_id = OBJECT_ID('qsh.QueryStoreRuntimeStats')
  ```

---

## 🚨 Troubleshooting

### Issue: "Project load failed"
**Solution**: Ensure SQL Workload is installed in SSDT
```
Visual Studio Installer → Workloads → SQL Server Data Tools
```

### Issue: "Schema 'qsh' already exists"
**Solution**: Existing schema detected. Review pre-deployment script:
```sql
-- Option 1: Drop existing (development only)
DROP SCHEMA qsh

-- Option 2: Alter existing (production)
-- Modify Schema/qsh.sql to use ALTER if exists
```

### Issue: "Primary key columns incorrect"
**Solution**: Verify SQLPROJ deployment:
```sql
EXEC sp_help 'qsh.QueryStoreRuntimeStats'
-- Check PK order matches: TenantName, ServerName, DatabaseName, ...
```

### Issue: "Indexes not created"
**Solution**: Rebuild indexes:
```sql
EXEC qsh.sp_MaintainIndexes @DebugMode = 0
```

---

## 📈 Next Steps

1. **✅ Build Project** in SSDT/Visual Studio
2. **✅ Deploy to Development** database
3. **✅ Test tenant-level queries** performance
4. **✅ Update ETL PowerShell** scripts
5. **✅ Test ETL with new PK structure**
6. **✅ Configure CI/CD pipeline** if applicable
7. **✅ Deploy to Production**
8. **✅ Migrate existing data** (if applicable)

---

## 📚 Files Generated

### Location: `c:\Source\TGQS\DBA_DWH\`

**Project File**:
- `DBA_DWH.sqlproj` - Main project manifest

**Schema Objects** (1):
- `Schema/qsh.sql` - Creates schema

**Table Objects** (8):
- Tables with optimized multi-tenant PKs
- 20+ supporting nonclustered indexes
- All constraints and defaults

**View Objects** (8):
- 4 Dimension views (Query, Plan, Interval, WaitCategory)
- 4 Fact views (RuntimeStats, WaitStats, TopQueries, WaitSummary)
- Pre-aggregation for Power BI performance

**Procedure Objects** (7):
- MERGE procedures with SCD Type 2
- Regression detection
- Maintenance & cleanup
- Analysis & reporting

---

## 📞 Support

For SQLPROJ-specific questions:
- [Microsoft SQL Database Projects](https://learn.microsoft.com/en-us/sql/ssdt/sql-server-data-tools)
- [SSDT GitHub Issues](https://github.com/microsoft/DACExtensions)

For deployment questions:
- [Azure SQL Deploy Options](https://learn.microsoft.com/en-us/azure/azure-sql/database/deployment-options)

---

**Status**: ✅ SQL Database Project Ready for Deployment  
**Created**: 2026-05-26  
**Version**: 1.0 (Multi-tenant optimized PKs)
