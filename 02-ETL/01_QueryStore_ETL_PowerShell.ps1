# ================================================================================
# Query Store Historical Data Warehouse - ETL Script
# Purpose: Extract Query Store data from source servers and load to central repository
# Requirements: dbatools module, SQL Server PowerShell module
# Author: GitHub Copilot
# Date: 2026-05-26
# ================================================================================

param(
    [string]$SourceServersFile = "SourceServers.json",
    [string]$TargetServer = "target-server.database.windows.net",
    [string]$TargetDatabase = "HistoricalQueryStore",
    [string]$TargetUsername = "",
    [string]$TargetPassword = "",
    [switch]$UseWindowsAuthentication = $false,
    [int]$BulkCopyTimeout = 300,
    [int]$QueryTimeout = 300
)

# ================================================================================
# CONFIGURATION
# ================================================================================

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Logging setup
$LogPath = ".\Logs"
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}
$LogFile = Join-Path $LogPath "QueryStoreETL_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ================================================================================
# HELPER FUNCTIONS
# ================================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

function Test-ModuleAvailable {
    param([string]$ModuleName)
    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Log "Module $ModuleName is available" "SUCCESS"
        return $true
    }
    else {
        Write-Log "Module $ModuleName is NOT available. Install with: Install-Module $ModuleName" "ERROR"
        return $false
    }
}

function Invoke-QueryStoreExtraction {
    param(
        [string]$SourceServer,
        [string]$SourceDatabase,
        [string]$TenantName,
        [PSCredential]$SourceCredential,
        [string]$TargetServer,
        [string]$TargetDatabase,
        [PSCredential]$TargetCredential
    )

    Write-Log "Starting extraction from $SourceServer.$SourceDatabase for tenant $TenantName"
    
    $startTime = Get-Date
    
    try {
        # Step 1: Flush Query Store to ensure all data is persisted
        Write-Log "Flushing Query Store on source database..."
        $flushQuery = "EXEC sp_query_store_flush_db;"
        
        if ($SourceCredential) {
            Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $flushQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout
        }
        else {
            Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $flushQuery -CommandTimeout $QueryTimeout
        }
        
        Write-Log "Query Store flushed successfully"

        # Step 2: Extract RuntimeStatsInterval
        Write-Log "Extracting RuntimeStatsInterval..."
        $intervalQuery = @"
SELECT 
    runtime_stats_interval_id AS RuntimeStatsIntervalId,
    '$TenantName' AS TenantName,
    CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS ServerName,
    start_time AS IntervalStartTime,
    end_time AS IntervalEndTime,
    DATEDIFF(MINUTE, start_time, end_time) AS IntervalDurationMinutes,
    CAST(start_time AS DATE) AS CapturedDate,
    CAST(start_time AS TIME) AS CapturedTime
FROM sys.query_store_runtime_stats_interval
WHERE start_time >= DATEADD(DAY, -7, GETUTC())
"@
        
        if ($SourceCredential) {
            $intervals = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $intervalQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout -As PSObject
        }
        else {
            $intervals = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $intervalQuery -CommandTimeout $QueryTimeout -As PSObject
        }
        
        Write-Log "Extracted $($intervals.Count) intervals"

        # Step 3: Extract QueryStoreQuery
        Write-Log "Extracting QueryStoreQuery..."
        $queryQuery = @"
SELECT 
    q.query_id AS QueryId,
    '$TenantName' AS TenantName,
    CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS ServerName,
    DB_NAME() AS DatabaseName,
    q.query_text_id AS QueryTextId,
    q.context_settings_id AS ContextSettingsId,
    q.object_id AS ObjectId,
    q.creation_time AS CompilationStartTime,
    q.last_compile_start_time AS CompilationEndTime,
    q.last_compile_batch_id AS LastCompilationBatch,
    q.last_compile_batch_time_ms AS LastCompilationBatchUTC,
    q.count_compiles AS CompilationCount,
    q.avg_compile_cpu_time_ms AS AvgCompileCpuTimeMs,
    q.max_compile_cpu_time_ms AS MaxCompileCpuTimeMs,
    q.avg_compile_memory_mb AS AvgCompileMemoryMb,
    q.max_compile_memory_mb AS MaxCompileMemoryMb
FROM sys.query_store_query q
WHERE q.creation_time >= DATEADD(DAY, -30, GETUTC())
"@
        
        if ($SourceCredential) {
            $queries = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $queryQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout -As PSObject
        }
        else {
            $queries = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $queryQuery -CommandTimeout $QueryTimeout -As PSObject
        }
        
        Write-Log "Extracted $($queries.Count) queries"

        # Step 4: Extract QueryStoreQueryText
        Write-Log "Extracting QueryStoreQueryText..."
        $textQuery = @"
SELECT 
    qt.query_text_id AS QueryTextId,
    '$TenantName' AS TenantName,
    CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS ServerName,
    DB_NAME() AS DatabaseName,
    qt.query_sql_text AS QueryTextContent,
    qt.statement_sql_handle AS StatementType,
    CONVERT(BINARY(8), CHECKSUM(qt.query_sql_text), 2) AS QueryHash,
    NULL AS QueryPlanHash
FROM sys.query_store_query_text qt
"@
        
        if ($SourceCredential) {
            $texts = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $textQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout -As PSObject
        }
        else {
            $texts = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $textQuery -CommandTimeout $QueryTimeout -As PSObject
        }
        
        Write-Log "Extracted $($texts.Count) query texts"

        # Step 5: Extract QueryStorePlan
        Write-Log "Extracting QueryStorePlan..."
        $planQuery = @"
SELECT 
    p.plan_id AS PlanId,
    '$TenantName' AS TenantName,
    CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS ServerName,
    DB_NAME() AS DatabaseName,
    p.query_id AS QueryId,
    p.engine_version AS EngineVersion,
    p.compatibility_level AS CompatibilityLevel,
    p.query_plan_hash AS QueryPlanHash,
    NULL AS QueryHash,
    p.plan_handle AS PlanHandle,
    p.creation_time AS CreationTime,
    p.last_execution_time AS LastExecutionTime,
    p.query_plan AS QueryPlanText,
    NULL AS IsOnlineIndexPlan,
    NULL AS IsParallelizable,
    NULL AS QueryPlanCompressed
FROM sys.query_store_plan p
"@
        
        if ($SourceCredential) {
            $plans = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $planQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout -As PSObject
        }
        else {
            $plans = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $planQuery -CommandTimeout $QueryTimeout -As PSObject
        }
        
        Write-Log "Extracted $($plans.Count) execution plans"

        # Step 6: Extract QueryStoreRuntimeStats
        Write-Log "Extracting QueryStoreRuntimeStats..."
        $runtimeQuery = @"
SELECT 
    rs.runtime_stats_id AS RuntimeStatsId,
    rs.runtime_stats_interval_id AS RuntimeStatsIntervalId,
    '$TenantName' AS TenantName,
    CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS ServerName,
    DB_NAME() AS DatabaseName,
    rs.query_id AS QueryId,
    rs.plan_id AS PlanId,
    rs.execution_type AS ExecutionType,
    CASE rs.execution_type
        WHEN 0 THEN 'Regular'
        WHEN 1 THEN 'Aborted'
        WHEN 2 THEN 'Exception'
    END AS ExecutionTypeDesc,
    rs.count_executions AS CountExecutions,
    rs.avg_duration_ms AS AvgDurationMs,
    rs.max_duration_ms AS MaxDurationMs,
    rs.min_duration_ms AS MinDurationMs,
    rs.stdev_duration_ms AS StdevDurationMs,
    rs.avg_logical_io_reads AS AvgLogicalIoReads,
    rs.max_logical_io_reads AS MaxLogicalIoReads,
    rs.min_logical_io_reads AS MinLogicalIoReads,
    rs.avg_logical_io_writes AS AvgLogicalIoWrites,
    rs.max_logical_io_writes AS MaxLogicalIoWrites,
    rs.min_logical_io_writes AS MinLogicalIoWrites,
    rs.avg_physical_io_reads AS AvgPhysicalIoReads,
    rs.max_physical_io_reads AS MaxPhysicalIoReads,
    rs.min_physical_io_reads AS MinPhysicalIoReads,
    rs.avg_cpu_time_ms AS AvgCpuTimeMs,
    rs.max_cpu_time_ms AS MaxCpuTimeMs,
    rs.min_cpu_time_ms AS MinCpuTimeMs,
    rs.avg_clr_time_ms AS AvgClrTimeMs,
    rs.max_clr_time_ms AS MaxClrTimeMs,
    rs.min_clr_time_ms AS MinClrTimeMs,
    rs.avg_elapsed_time_ms AS AvgElapsedTimeMs,
    rs.max_elapsed_time_ms AS MaxElapsedTimeMs,
    rs.min_elapsed_time_ms AS MinElapsedTimeMs,
    rs.avg_memory_used_mb AS AvgMemoryUsedMb,
    rs.max_memory_used_mb AS MaxMemoryUsedMb,
    rs.min_memory_used_mb AS MinMemoryUsedMb,
    rs.avg_rowcount AS AvgRowCount,
    rs.max_rowcount AS MaxRowCount,
    rs.min_rowcount AS MinRowCount
FROM sys.query_store_runtime_stats rs
WHERE rs.runtime_stats_interval_id >= 
    (SELECT MAX(runtime_stats_interval_id) - 100 FROM sys.query_store_runtime_stats_interval)
"@
        
        if ($SourceCredential) {
            $runtimeStats = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $runtimeQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout -As PSObject
        }
        else {
            $runtimeStats = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $runtimeQuery -CommandTimeout $QueryTimeout -As PSObject
        }
        
        Write-Log "Extracted $($runtimeStats.Count) runtime statistics records"

        # Step 7: Extract QueryStoreWaitStats
        Write-Log "Extracting QueryStoreWaitStats..."
        $waitQuery = @"
SELECT 
    rs.runtime_stats_interval_id AS RuntimeStatsIntervalId,
    '$TenantName' AS TenantName,
    CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS ServerName,
    DB_NAME() AS DatabaseName,
    rs.query_id AS QueryId,
    rs.plan_id AS PlanId,
    wc.wait_category_desc AS WaitCategory,
    wc.wait_category AS WaitCategoryId,
    ws.total_query_wait_time_ms AS TotalWaitTimeMs,
    ws.avg_query_wait_time_ms AS AvgWaitTimeMs,
    ws.max_query_wait_time_ms AS MaxWaitTimeMs,
    ws.stdev_query_wait_time_ms AS StdevWaitTimeMs,
    ws.query_wait_time_bucket_id AS QueryWaitTimeCategory,
    ws.count_executions AS CountWaits
FROM sys.query_store_runtime_stats rs
CROSS APPLY (
    SELECT 
        wait_category,
        wait_category_desc,
        SUM(total_query_wait_time_ms) AS total_query_wait_time_ms,
        AVG(avg_query_wait_time_ms) AS avg_query_wait_time_ms,
        MAX(max_query_wait_time_ms) AS max_query_wait_time_ms,
        STDEV(avg_query_wait_time_ms) AS stdev_query_wait_time_ms,
        query_wait_time_bucket_id,
        SUM(count_executions) AS count_executions
    FROM sys.query_store_wait_stats
    WHERE query_id = rs.query_id 
        AND plan_id = rs.plan_id
        AND runtime_stats_interval_id = rs.runtime_stats_interval_id
    GROUP BY wait_category, wait_category_desc, query_wait_time_bucket_id
) ws
CROSS APPLY (SELECT wait_category, wait_category_desc FROM sys.query_store_wait_stats_categories wc
    WHERE wc.wait_category = ws.wait_category) wc
WHERE rs.runtime_stats_interval_id >= 
    (SELECT MAX(runtime_stats_interval_id) - 100 FROM sys.query_store_runtime_stats_interval)
"@
        
        if ($SourceCredential) {
            $waitStats = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $waitQuery -Credential $SourceCredential -CommandTimeout $QueryTimeout -As PSObject
        }
        else {
            $waitStats = Invoke-DbaQuery -SqlInstance $SourceServer -Database $SourceDatabase -Query $waitQuery -CommandTimeout $QueryTimeout -As PSObject
        }
        
        Write-Log "Extracted $($waitStats.Count) wait statistics records"

        # Step 8: Load data to target using Write-DbaDbTableData
        Write-Log "Loading data to target database..."
        
        # Prepare target connection
        if ($UseWindowsAuthentication) {
            $targetSplat = @{
                SqlInstance = $TargetServer
                Database = $TargetDatabase
                CommandTimeout = $BulkCopyTimeout
            }
        }
        else {
            $targetSplat = @{
                SqlInstance = $TargetServer
                Database = $TargetDatabase
                Credential = $TargetCredential
                CommandTimeout = $BulkCopyTimeout
            }
        }

        # Load each dataset
        if ($intervals.Count -gt 0) {
            Write-DbaDbTableData -InputObject $intervals -SqlInstance $TargetServer -Database $TargetDatabase -Table "qsh.RuntimeStatsInterval" -BulkCopyTimeout $BulkCopyTimeout @targetSplat
            Write-Log "Loaded $($intervals.Count) interval records"
        }

        if ($queries.Count -gt 0) {
            Write-DbaDbTableData -InputObject $queries -SqlInstance $TargetServer -Database $TargetDatabase -Table "qsh.QueryStoreQuery" -BulkCopyTimeout $BulkCopyTimeout @targetSplat
            Write-Log "Loaded $($queries.Count) query records"
        }

        if ($texts.Count -gt 0) {
            Write-DbaDbTableData -InputObject $texts -SqlInstance $TargetServer -Database $TargetDatabase -Table "qsh.QueryStoreQueryText" -BulkCopyTimeout $BulkCopyTimeout @targetSplat
            Write-Log "Loaded $($texts.Count) query text records"
        }

        if ($plans.Count -gt 0) {
            Write-DbaDbTableData -InputObject $plans -SqlInstance $TargetServer -Database $TargetDatabase -Table "qsh.QueryStorePlan" -BulkCopyTimeout $BulkCopyTimeout @targetSplat
            Write-Log "Loaded $($plans.Count) plan records"
        }

        if ($runtimeStats.Count -gt 0) {
            Write-DbaDbTableData -InputObject $runtimeStats -SqlInstance $TargetServer -Database $TargetDatabase -Table "qsh.QueryStoreRuntimeStats" -BulkCopyTimeout $BulkCopyTimeout @targetSplat
            Write-Log "Loaded $($runtimeStats.Count) runtime stats records"
        }

        if ($waitStats.Count -gt 0) {
            Write-DbaDbTableData -InputObject $waitStats -SqlInstance $TargetServer -Database $TargetDatabase -Table "qsh.QueryStoreWaitStats" -BulkCopyTimeout $BulkCopyTimeout @targetSplat
            Write-Log "Loaded $($waitStats.Count) wait stats records"
        }

        $duration = (Get-Date) - $startTime
        Write-Log "Extraction and loading completed successfully in $($duration.TotalSeconds) seconds" "SUCCESS"
        
        return @{
            Status = "SUCCESS"
            Duration = $duration
            RecordsLoaded = $intervals.Count + $queries.Count + $texts.Count + $plans.Count + $runtimeStats.Count + $waitStats.Count
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Error during extraction: $errorMsg" "ERROR"
        
        return @{
            Status = "FAILED"
            Error = $errorMsg
        }
    }
}

# ================================================================================
# MAIN EXECUTION
# ================================================================================

Write-Log "Query Store ETL Process Started"
Write-Log "==============================================="

# Check for required modules
$requiredModules = @("dbatools", "SqlServer")
$allModulesAvailable = $true

foreach ($module in $requiredModules) {
    if (-not (Test-ModuleAvailable $module)) {
        $allModulesAvailable = $false
    }
}

if (-not $allModulesAvailable) {
    Write-Log "Please install missing modules and run again" "ERROR"
    exit 1
}

# Load source servers configuration
if (-not (Test-Path $SourceServersFile)) {
    Write-Log "Source servers file not found: $SourceServersFile" "ERROR"
    Write-Log "Create a JSON file with this structure:" "INFO"
    Write-Host @"
{
    "servers": [
        {
            "serverName": "sql-server-01",
            "tenantName": "Tenant1",
            "databases": ["Database1", "Database2"],
            "useWindowsAuth": true
        },
        {
            "serverName": "sql-server-02.database.windows.net",
            "tenantName": "Tenant2",
            "databases": ["Database1"],
            "useWindowsAuth": false,
            "username": "dbuser",
            "password": "password"
        }
    ]
}
"@
    exit 1
}

try {
    $sourceServersConfig = Get-Content $SourceServersFile | ConvertFrom-Json
}
catch {
    Write-Log "Error parsing source servers configuration: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Process each source server
$totalResults = @{
    SuccessfulExtractions = 0
    FailedExtractions = 0
    TotalRecordsLoaded = 0
}

foreach ($server in $sourceServersConfig.servers) {
    Write-Log "Processing server: $($server.serverName)"
    
    # Prepare credentials for source if needed
    $sourceCredential = $null
    if (-not $server.useWindowsAuth) {
        $sourceCredential = New-Object System.Management.Automation.PSCredential(
            $server.username,
            (ConvertTo-SecureString $server.password -AsPlainText -Force)
        )
    }

    # Process each database
    foreach ($db in $server.databases) {
        Write-Log "Processing database: $db"
        
        $result = Invoke-QueryStoreExtraction `
            -SourceServer $server.serverName `
            -SourceDatabase $db `
            -TenantName $server.tenantName `
            -SourceCredential $sourceCredential `
            -TargetServer $TargetServer `
            -TargetDatabase $TargetDatabase `
            -TargetCredential $TargetCredential

        if ($result.Status -eq "SUCCESS") {
            $totalResults.SuccessfulExtractions++
            $totalResults.TotalRecordsLoaded += $result.RecordsLoaded
        }
        else {
            $totalResults.FailedExtractions++
        }
    }
}

Write-Log "==============================================="
Write-Log "ETL Process Completed" "SUCCESS"
Write-Log "Successful Extractions: $($totalResults.SuccessfulExtractions)"
Write-Log "Failed Extractions: $($totalResults.FailedExtractions)"
Write-Log "Total Records Loaded: $($totalResults.TotalRecordsLoaded)"
Write-Log "Log file: $LogFile"
