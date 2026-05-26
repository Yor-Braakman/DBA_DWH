# SQL Database Project - Query Store Historical Data Warehouse

## Project Structure

```
DBA_DWH/
├── DBA_DWH.sqlproj                      (SQL Project file with object references)
│
├── Schema/
│   └── qsh.sql                           (Creates qsh schema)
│
├── Tables/                               (8 table definitions)
│   ├── RuntimeStatsInterval.sql          (Time dimension - PK: TenantName, ServerName, RuntimeStatsIntervalId)
│   ├── QueryStoreQuery.sql               (Query metadata - PK: TenantName, ServerName, DatabaseName, QueryId)
│   ├── QueryStoreQueryText.sql           (Query text - PK: TenantName, ServerName, DatabaseName, QueryTextId)
│   ├── QueryStorePlan.sql                (Execution plans - PK: TenantName, ServerName, DatabaseName, PlanId)
│   ├── QueryStoreRuntimeStats.sql        (FACT - PK: TenantName, ServerName, DatabaseName, RuntimeStatsId, RuntimeStatsIntervalId)
│   ├── QueryStoreWaitStats.sql           (FACT - PK: TenantName, ServerName, DatabaseName, WaitStatsId, RuntimeStatsIntervalId)
│   ├── ETLControl.sql                    (ETL logging - PK: TenantName, ServerName, DatabaseName, ETLControlId)
│   └── PlanRegressions.sql               (Regression tracking - PK: TenantName, ServerName, DatabaseName, RegressionId)
│
├── Views/                                (8 semantic layer views)
│   ├── DimQuery.sql                      (Query dimension with text)
│   ├── DimPlan.sql                       (Plan dimension with age calculation)
│   ├── DimInterval.sql                   (Time dimension for aggregation)
│   ├── DimWaitCategory.sql               (Wait category reference)
│   ├── FactRuntimeStats.sql              (Aggregated performance metrics)
│   ├── FactWaitStats.sql                 (Wait analysis by category)
│   ├── FactTopQueries.sql                (Pre-aggregated top queries)
│   └── FactWaitSummary.sql               (Aggregated wait statistics)
│
└── Procedures/                           (7 operational procedures)
    ├── sp_MERGE_QueryStoreRuntimeStats.sql  (SCD Type 2 + regression detection)
    ├── sp_MERGE_QueryStoreWaitStats.sql     (Wait stats merge)
    ├── sp_MERGE_QueryDimensions.sql         (Dimension table upserts)
    ├── sp_CleanupHistoricalData.sql         (Data retention policy)
    ├── sp_MaintainIndexes.sql               (Index fragmentation management)
    ├── sp_UpdateStatistics.sql              (Query optimizer stats)
    └── sp_AnalyzeStorageUsage.sql           (Capacity reporting)
```

## Key Design Changes

### Primary Key Structure (Multi-Tenant First)

All primary keys now follow this pattern:
```
(TenantName, ServerName, DatabaseName, [other natural key columns])
```

#### Benefits:
✅ **Better data granularity**: Filter by tenant/server/database first  
✅ **Improved query performance**: Tenant-level partitioning support  
✅ **Easier management**: Single tenant cleanup/maintenance  
✅ **Hierarchical filtering**: Natural filtering in Power BI  

### Example PKs:

| Table | Primary Key |
|-------|-------------|
| RuntimeStatsInterval | (TenantName, ServerName, RuntimeStatsIntervalId) |
| QueryStoreQuery | (TenantName, ServerName, DatabaseName, QueryId) |
| QueryStoreRuntimeStats | (TenantName, ServerName, DatabaseName, RuntimeStatsId, RuntimeStatsIntervalId) |
| PlanRegressions | (TenantName, ServerName, DatabaseName, RegressionId) |

### Supporting Indexes

Each table includes optimized nonclustered indexes for common query patterns:
- Tenant/Server/Database filtering
- Performance analysis (duration, CPU, memory)
- Regression detection
- Wait category analysis

## Database Project Features

### Build Benefits
- Schema validation before deployment
- Dependency resolution
- Incremental deployment
- Version control friendly
- Pre/post-deployment script support

### Deployment Process
1. Right-click project → **Publish**
2. Select target database (Azure SQL or on-premises)
3. Preview changes
4. Deploy with one click

## Object Deployment Order

The SQL project automatically handles dependencies:
1. **Schema** creation (qsh.sql)
2. **Tables** with clustered indexes
3. **Supporting indexes** on tables
4. **Views** (reference tables/views)
5. **Procedures** (reference tables/views)

## Statistics & Metrics

### Total Objects
- **Tables**: 8 (2 dimensions, 2 facts + 4 control/tracking)
- **Views**: 8 (4 dimensions, 4 facts for Power BI)
- **Procedures**: 7 (MERGE, maintenance, analysis)
- **Indexes**: 20+ (clustered + nonclustered)

### Data Structure
- **Clustered Indexes**: Tenant→Server→Database→Identity keys
- **Nonclustered Indexes**: Query patterns, performance analysis, tenant filtering
- **Compression**: Supported via SQLPROJ build options

## Usage Examples

### Deploying via SQL Server Data Tools (SSDT)

```
File → New → Project → SQL Server Database Project
Project Configuration:
  - Target Platform: SQL Server 2022 / Azure SQL Database
  - Language Extensions: T-SQL
```

### Adding Objects to Project

All objects automatically tracked in `.sqlproj` file:
```xml
<ItemGroup>
  <Build Include="Tables\QueryStoreQuery.sql" />
  <Build Include="Views\DimQuery.sql" />
  <Build Include="Procedures\sp_MERGE_QueryStoreRuntimeStats.sql" />
</ItemGroup>
```

### Custom Build Configuration

```xml
<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
  <TargetConnectionString>
    Server=(local);Integrated Security=true;Pooling=false;Initial Catalog=HistoricalQueryStore
  </TargetConnectionString>
</PropertyGroup>
```

## Tenant-Aware Queries

With new PK structure, filtering is more efficient:

**Before (Key columns scattered)**
```sql
SELECT * FROM qsh.QueryStoreRuntimeStats
WHERE QueryId = 123 AND TenantName = 'Tenant_A'
-- Scans entire table
```

**After (Tenant columns first)**
```sql
SELECT * FROM qsh.QueryStoreRuntimeStats
WHERE TenantName = 'Tenant_A' AND ServerName = 'Server_1' AND QueryId = 123
-- Seeks into clustered index immediately
```

## Maintenance Procedures with Tenant Support

```sql
-- Run cleanup for specific tenant
EXEC qsh.sp_CleanupHistoricalData 
    @RetentionDays = 90,
    @TenantName = 'Tenant_A',
    @ServerName = 'Server_1',
    @DryRun = 1

-- Run for all tenants
EXEC qsh.sp_CleanupHistoricalData 
    @RetentionDays = 90,
    @DryRun = 0
```

## Building & Publishing

### Visual Studio / SSDT Steps
1. **Build** project (validates syntax)
2. **Publish** to database
3. **Generate Script** for CI/CD pipelines

### Command Line (SQLCMD)
```powershell
# Build DACPAC (deployment package)
msbuild DBA_DWH.sqlproj /p:Configuration=Debug

# Publish to Azure SQL
SqlPackage /Action:Publish /SourceFile:bin\Debug\DBA_DWH.dacpac `
  /TargetServerName:server.database.windows.net `
  /TargetDatabaseName:HistoricalQueryStore
```

## Version Control Integration

Recommended structure for Git:
```
DBA_DWH/
├── .gitignore              (Exclude bin/, obj/, logs/)
├── DBA_DWH.sqlproj
├── Tables/
├── Views/
├── Procedures/
└── Schema/
```

Example `.gitignore`:
```
bin/
obj/
*.dacpac
*.sqlproj.user
```

## Next Steps

1. **Build Project**: Validate all objects compile
2. **Deploy to Dev**: Test in development database
3. **Configure ETL**: Update PowerShell scripts with new PK structure
4. **Test Queries**: Verify tenant-level filtering performance
5. **Production Deployment**: Use SSDT Publish or SqlPackage

## References

- [SQL Database Projects](https://learn.microsoft.com/en-us/sql/ssdt/sql-server-data-tools)
- [DACPAC Files](https://learn.microsoft.com/en-us/sql/relational-databases/data-tier-applications/data-tier-applications)
- [SqlPackage Tool](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage)
