# Power BI Dashboard Setup Guide - Query Store Historical Analysis

## Overview
This guide walks through creating a comprehensive DBA dashboard in Power BI for Query Store analysis.

## Prerequisites
- Power BI Desktop (latest version)
- Network/firewall access to HistoricalQueryStore database
- Appropriate SQL database permissions (SELECT on qsh schema)
- 05-PowerBI/01_DAX_Measures.dax file

## Step 1: Connect to Data Source

### Import Data
1. Open Power BI Desktop
2. Click **Home → Get data → SQL Server**
3. Enter connection details:
   - **Server**: `target-server.database.windows.net` or `on-prem-server\SQLINSTANCE`
   - **Database**: `HistoricalQueryStore`
   - Click **OK**

### Authentication
- **For Azure SQL**: Select "Microsoft account" or "Database"
- **For On-Premises**: Select "Windows" or "Database"
- Click **Connect**

## Step 2: Select Data Tables/Views

Select the following views (check boxes):
- ✓ qsh.DimQuery
- ✓ qsh.DimPlan
- ✓ qsh.DimInterval
- ✓ qsh.DimWaitCategory
- ✓ qsh.FactRuntimeStats
- ✓ qsh.FactWaitStats
- ✓ qsh.FactTopQueries
- ✓ qsh.FactWaitSummary

Click **Load**

## Step 3: Create Data Model Relationships

Once data is loaded, Power BI should auto-detect relationships. Verify in Model view:

1. Go to **Model view** (left sidebar)
2. Verify these relationships exist:

| From Table | To Table | Relationship Field | Type |
|-----------|----------|-------------------|------|
| DimQuery | FactRuntimeStats | QueryDimKey | Many-to-One |
| DimPlan | FactRuntimeStats | PlanDimKey | Many-to-One |
| DimInterval | FactRuntimeStats | RuntimeStatsIntervalId | Many-to-One |
| DimWaitCategory | FactWaitStats | WaitCategoryId | Many-to-One |

### If Relationships Missing:
1. Drag source field to target field
2. Set relationship type: Many-to-One
3. Mark as active relationship

## Step 4: Add DAX Measures

1. In **Report view**, right-click **FactRuntimeStats** table
2. Select **New measure**
3. Copy each measure from `01_DAX_Measures.dax`

**Example - Add first measure:**
```dax
Avg Duration (seconds) = AVERAGE(FactRuntimeStats[AvgDurationSeconds])
```

4. Repeat for all ~40 measures in the DAX file

**Pro Tip**: Create measure groups by category (Performance, Wait, Regression, etc.)

## Step 5: Create Report Pages

### Page 1: Executive Dashboard

**Layout:**
- Top row: 3 KPI cards (Avg Duration, Execution Count, CPU Time)
- Middle: Line chart (Duration trend over time)
- Bottom: Table (Top 20 queries by duration)

**Visualizations:**
```
┌──────────────────────────────────────────────┐
│  Avg Duration │ Total Executions │ Max CPU  │
│     (s)       │                  │   (ms)   │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│        Duration Trend (7 Days)               │
│     Line chart with server/tenant filter    │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│  Top 20 Queries by Duration                  │
│  Query ID | Avg Dur | Max Dur | Exec Count  │
└──────────────────────────────────────────────┘
```

### Page 2: Query Performance Analysis

**Layout:**
- Left: Slicers (Server, Tenant, Database, Date Range)
- Top right: Query selector (dropdown or search)
- Bottom: Performance metrics detail

**Visualizations:**
1. **Query Metrics Table**
   - Columns: Query ID, Avg Duration, Max Duration, CPU Time, Memory, IO
   - Conditional formatting: Color scale (red=slow, green=fast)

2. **Execution Timeline**
   - Area chart: Execution count by day

3. **Performance Indicators**
   - Gauge charts: Current vs. previous period % change

### Page 3: Wait Analysis

**Layout:**
- Slicers: Server, Tenant, Wait Category
- Visualizations to display wait breakdown

**Visualizations:**
1. **Wait Category Breakdown**
   - Pie or Donut chart: % by wait category
   - Categories: CPU, Memory, IO, Lock, Latch, Network, Other

2. **Wait Trends**
   - Stacked area chart: Wait time by category over time

3. **Top Wait-Causing Queries**
   - Horizontal bar: Query ID vs. Total Wait Time
   - Show wait category by color

4. **KPIs**
   - Card: Total Wait Hours
   - Card: Avg Wait Time (ms)
   - Card: Max Wait Time (ms)

### Page 4: Plan Regression Detection

**Layout:**
- Timeline slider: Date range selector
- Main table: Regression details

**Visualizations:**
1. **Regression Timeline**
   - Line chart: Count of regressions detected over time

2. **Affected Queries**
   - Table with columns:
     - Query ID
     - Tenant
     - Server
     - Detection Date
     - Duration Change %
     - Old Plan ID
     - New Plan ID
     - Notes (editable field)

3. **Top Regressions**
   - Bar chart: Query ID vs. Duration Change %
   - Threshold line at 25% increase

4. **Action Items**
   - Summarize queries needing attention
   - Show investigation status

### Page 5: Multi-Tenant Comparison

**Layout:**
- Slicers: Tenant, Server, Date Range
- Comparative metrics

**Visualizations:**
1. **Tenant Comparison Matrix**
   - Table by tenant showing:
     - Query Count
     - Avg Duration
     - Total CPU Hours
     - Total Wait Hours
     - Regression Count

2. **Resource Consumption by Tenant**
   - Clustered bar chart:
     - X-axis: Tenant
     - Y-axis: CPU Hours, Memory, IO (dual axis)

3. **Server Performance Comparison**
   - Map or table showing server health metrics

4. **Trend Comparison**
   - Multi-line chart: Duration trend by tenant

## Step 6: Add Slicers & Filters

Add slicers to each report page:

1. **Date Range Slicer**
   - Field: `DimInterval[IntervalDate]`
   - Type: Between
   - Default: Last 30 days

2. **Tenant Slicer**
   - Field: `FactRuntimeStats[TenantName]`
   - Type: List (dropdown)

3. **Server Slicer**
   - Field: `FactRuntimeStats[ServerName]`
   - Type: List

4. **Database Slicer**
   - Field: `FactRuntimeStats[DatabaseName]`
   - Type: List

5. **Query Filter**
   - Field: `DimQuery[QueryId]` or `DimQuery[QueryText]`
   - Type: Search box (for large datasets)

## Step 7: Configure Report Settings

1. **Page Display:**
   - Go to **View → Page view**
   - Select desired view mode

2. **Theme:**
   - Apply consistent color scheme (corporate branding)
   - Use Power BI themes: **View → Themes**

3. **Tooltips:**
   - Create custom tooltip page for drill-down details
   - Show: Query text, execution history, wait breakdown

4. **Bookmarks:**
   - Create bookmarks for common views:
     - "Top 10 Slow Queries"
     - "High Memory Usage"
     - "Recent Regressions"

## Step 8: Publish to Power BI Service

### For Cloud Deployment:
1. Click **Home → Publish**
2. Select target workspace
3. Click **Select**

### Configure Refresh Schedule:
1. Go to Power BI Service (app.powerbi.com)
2. Find dataset in workspace
3. **Settings → Refresh schedule**
4. Set schedule: Daily at 3:30 AM (after ETL completes)

### Share with Team:
1. Right-click report → **Share**
2. Add team members
3. Set permissions: View or Edit

## Step 9: Advanced Features

### Q&A (Natural Language)
- Enable Q&A on dashboard
- Users can ask: "What's the average query duration?" 
- Train with suggested questions

### Row-Level Security (RLS)
For multi-tenant scenarios, implement RLS:

```dax
// Role: Tenant_A_User
[TenantName] = "Tenant_A"
```

### Performance Optimization
For large datasets (>50M rows):

1. **Aggregations**
   - Pre-aggregate by server/tenant/day
   - Use aggregation tables

2. **Incremental Refresh**
   - Only load new data daily
   - Archive older data in separate partition

3. **DirectQuery** (alternative to Import)
   - Connect live to database (slower but always current)
   - Use for real-time dashboards

## Step 10: Create Alerts & Notifications

Set up alerting rules:

1. **Duration Alert**
   - If Avg Duration > 5 seconds → Email team

2. **Regression Alert**
   - If new regression detected → Notification

3. **Resource Alert**
   - If CPU Hours > threshold → Warning

Configure in Power BI Service:
1. Open report
2. **File → Alerts**
3. Set condition and notification method

## Sample DAX Formulas for Additional Measures

```dax
// Top Queries Count
Top Queries = 
COUNTROWS(
    TOPN(10, 
        SUMMARIZE(VALUES(DimQuery[QueryId]), 
            "Duration", [Avg Duration (seconds)]),
        [Duration],
        DESC
    )
)

// Query Duration Improvement
Duration Improvement % = 
VAR CurrentAvg = [Avg Duration (seconds)]
VAR BaselineAvg = CALCULATE([Avg Duration (seconds)], 
    DATEADD(DimInterval[IntervalDate], -30, DAY))
RETURN (BaselineAvg - CurrentAvg) / BaselineAvg * 100

// Regression Risk Score
Regression Risk Score = 
IF([Plan Instability Count] > 0,
    [Regression Count] * 10 + [Duration Change (%)] / 10,
    0
)
```

## Troubleshooting Power BI Dashboard

### Issue: Measures show blank
- **Solution**: Verify data loaded correctly, check FILTER conditions in DAX

### Issue: Slow report performance
- **Solution**: Use aggregation tables, reduce row context, enable query folding

### Issue: Slicer not filtering visuals
- **Solution**: Check relationship directions, verify active relationship

### Issue: Data doesn't refresh
- **Solution**: Check Power BI Service refresh schedule, verify data source credentials

## Export & Sharing Options

1. **Export Report**
   - **File → Export → PDF** for stakeholder emails

2. **Share Dashboard Link**
   - Share Power BI report link with read-only access

3. **Embed in SharePoint**
   - Embed Power BI report in SharePoint Online

4. **Export Data**
   - **Right-click visual → Export data** to Excel

## Next Steps

1. Customize dashboard for your organization
2. Train DBA team on interpreting metrics
3. Set up alerting and automation
4. Integrate with incident management system
5. Schedule weekly/monthly review meetings
