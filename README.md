# Query Store Historical Data Warehouse - Quick Start

## 📋 What is This?

A complete solution for centralizing SQL Server Query Store data from multiple instances into a single data warehouse, enabling historical trend analysis, plan regression detection, and multi-tenant DBA dashboarding via Power BI.

## 🏗️ Project Structure

```
TGQS/
├── 01-DDL/                          # Database schema creation
│   └── 01_Create_HistoricalQueryStore_Schema.sql
│
├── 02-ETL/                          # Data extraction & loading
│   ├── 01_QueryStore_ETL_PowerShell.ps1
│   ├── 02_MERGE_SCD_Type2_Logic.sql
│   └── SourceServers.json.template
│
├── 03-DataModeling/                 # Semantic layer for Power BI
│   └── 01_Create_DataModeling_Views.sql
│
├── 04-Maintenance/                  # Retention & optimization
│   └── 01_Maintenance_Procedures.sql
│
├── 05-PowerBI/                      # Dashboard & measures
│   ├── 01_DAX_Measures.dax
│   └── 02_Dashboard_Setup_Guide.md
│
└── 06-Documentation/                # Complete guides
    └── 01_Implementation_Guide.md
```

## 🚀 Quick Start (5 Minutes)

### 1. Create Target Database
```sql
CREATE DATABASE HistoricalQueryStore 
    (EDITION = 'Standard', SERVICE_OBJECTIVE = 'S1')
```

### 2. Create Schema
```sql
USE HistoricalQueryStore
GO
-- Execute: 01-DDL/01_Create_HistoricalQueryStore_Schema.sql
```

### 3. Create Views
```sql
-- Execute: 03-DataModeling/01_Create_DataModeling_Views.sql
```

### 4. Configure ETL
```powershell
# Copy template and customize
Copy-Item "02-ETL/SourceServers.json.template" "02-ETL/SourceServers.json"

# Edit SourceServers.json with your servers
# Install prerequisites
Install-Module dbatools -Force
Install-Module SqlServer -Force
```

### 5. Run ETL
```powershell
cd "02-ETL"
.\01_QueryStore_ETL_PowerShell.ps1 `
    -TargetServer "your-server.database.windows.net" `
    -TargetDatabase "HistoricalQueryStore" `
    -TargetUsername "admin@company.com" `
    -TargetPassword "Password123!"
```

### 6. Connect Power BI
- New report → SQL Server → HistoricalQueryStore
- Load: DimQuery, DimPlan, FactRuntimeStats, FactWaitStats, etc.
- Copy measures from 05-PowerBI/01_DAX_Measures.dax

## 📊 What Gets You?

| Component | Purpose | Benefit |
|-----------|---------|---------|
| **8 Core Tables** | Store Query Store data + context | Multi-tenant historical archive |
| **8 Data Views** | Dimensions & Facts for analysis | Clean semantic model for Power BI |
| **40+ DAX Measures** | Pre-built KPIs | Instant analysis & dashboards |
| **Regression Detection** | Auto-identify plan changes | Proactive performance management |
| **Maintenance Scripts** | Data retention & optimization | Automatic cleanup & performance tuning |
| **PowerShell ETL** | Automated data collection | Schedule & forget extraction |

## 🔄 Data Flow

```
Multiple SQL Servers (sys.query_store_*)
           ↓
     PowerShell/dbatools
           ↓
    HistoricalQueryStore
     (Central Repository)
           ↓
      Data Modeling Views
           ↓
    Power BI Dashboard
     (Executive Reporting)
```

## 📈 Key Features

### ✅ Multi-Tenancy
Every record tagged with: TenantName, ServerName, DatabaseName

### ✅ Historical Tracking
- 90-day retention (configurable)
- Complete audit trail of query performance
- Plan change timeline

### ✅ Automatic Regression Detection
- Flags queries that moved to slower plans
- Tracks duration increase %
- Enables proactive tuning

### ✅ Wait Analysis
- Breaks down time by wait category (CPU, Memory, IO, Lock, etc.)
- Identifies bottlenecks
- Correlates with query performance

### ✅ Performance Dashboards
- Pre-built 5-page Power BI report template
- Top N queries, trends, comparisons
- Server/tenant slicing

## 🔧 Configuration

### ETL Frequency
- **Default**: Daily at 03:00 AM
- **Adjustable**: Modify Windows Task Scheduler

### Data Retention
- **Default**: 90 days
- **Run maintenance**:
  ```sql
  EXEC qsh.sp_CleanupHistoricalData @RetentionDays=90, @DryRun=0
  ```

### Thresholds
Modify regression detection in sp_MERGE_QueryStoreRuntimeStats:
- Default: 25% performance increase = regression
- Adjust: `((AVG(rs.AvgDurationMs) - AVG(rh.AvgDurationMs)) / NULLIF(AVG(rh.AvgDurationMs), 0)) > 0.25`

## 📋 Implementation Checklist

- [ ] Create HistoricalQueryStore database
- [ ] Run 01-DDL schema creation script
- [ ] Run 03-DataModeling views script  
- [ ] Deploy 04-Maintenance procedures
- [ ] Deploy 02-ETL MERGE logic
- [ ] Install PowerShell modules (dbatools, SqlServer)
- [ ] Configure SourceServers.json
- [ ] Test ETL script on one server/database
- [ ] Schedule ETL with Task Scheduler
- [ ] Connect Power BI to data warehouse
- [ ] Add DAX measures to Power BI model
- [ ] Build sample dashboards
- [ ] Train DBA team
- [ ] Set up alerting on regressions
- [ ] Schedule daily maintenance job

## 🎯 Common Use Cases

### "Which queries got slower after the update?"
1. Filter by date range (before/after update)
2. Check Regression Alerts page
3. Compare old vs new plan execution stats

### "Where is our CPU time spent?"
1. Go to Top Queries page
2. Sort by CPU Time
3. Click to drill into specific query
4. Review wait analysis

### "How is Tenant A performing vs Tenant B?"
1. Multi-Tenant Comparison page
2. Use tenant slicer
3. Compare metrics side-by-side

### "Which server has the most regressions?"
1. Plan Regression Detection page
2. Use server slicer
3. Review trend chart
4. Investigate affected queries

## 🚨 Troubleshooting

**"PowerShell can't find dbatools module"**
```powershell
Install-Module dbatools -Repository PSGallery -Force
```

**"ETL script times out"**
- Increase `-BulkCopyTimeout` parameter
- Run during off-peak hours
- Check network connectivity

**"Power BI measures show blank"**
- Verify data loaded (check row counts in views)
- Refresh Power BI dataset
- Verify relationship directions

**"Regression detection not working"**
- Ensure SCD Type 2 logic deployed
- Check if data has multiple plans per query
- Verify regression threshold

For detailed troubleshooting, see: **06-Documentation/01_Implementation_Guide.md**

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| 01_Implementation_Guide.md | Complete setup instructions |
| 02_Dashboard_Setup_Guide.md | Power BI configuration steps |
| 01_DAX_Measures.dax | 40+ pre-built measures |
| This file (README.md) | Quick reference |

## 🔐 Security Considerations

1. **Credentials**: Store SourceServers.json securely (consider Azure Key Vault)
2. **Database Permissions**: Grant SELECT on qsh schema only to Power BI users
3. **Row-Level Security**: Implement RLS if tenants should only see their data
4. **Network**: Enable firewall rules for ETL and Power BI connections

## 📊 Performance Expectations

| Operation | Typical Duration | Notes |
|-----------|------------------|-------|
| ETL (10 servers) | 15-30 minutes | Bulk load speed |
| Daily Maintenance | 5-10 minutes | Index + stats |
| Power BI Load | 1-5 minutes | 90 days of data |
| Query Response | <1 second | View-based, indexed |

## 🎓 Learning Path

1. **Day 1**: Review architecture (06-Documentation/01_Implementation_Guide.md)
2. **Day 2**: Deploy schema (01-DDL)
3. **Day 3**: Configure ETL (02-ETL)
4. **Day 4**: Create data views (03-DataModeling)
5. **Day 5**: Build Power BI dashboard (05-PowerBI)

## 🤝 Contributing

To extend this solution:
- Add custom views in 03-DataModeling
- Create organization-specific measures in 05-PowerBI
- Extend maintenance logic in 04-Maintenance
- Document in 06-Documentation

## 📝 License & Attribution

This solution was developed using GitHub Copilot based on Microsoft SQL Server Query Store best practices.

## 🆘 Support

For issues or questions:
1. Check troubleshooting section above
2. Review 06-Documentation/01_Implementation_Guide.md
3. Verify SQL permissions and network connectivity
4. Check ETL logs in ./Logs directory

## 📞 Contact

Developed with GitHub Copilot
For SQL Server Query Store best practices: [Microsoft Docs](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)

---

**Version**: 1.0  
**Last Updated**: 2026-05-26  
**Status**: ✅ Production Ready
