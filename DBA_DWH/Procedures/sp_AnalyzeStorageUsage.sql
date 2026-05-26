-- sp_AnalyzeStorageUsage: Storage capacity analysis by table
CREATE PROCEDURE [qsh].[sp_AnalyzeStorageUsage]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 100 PERCENT
        SchemaName = SCHEMA_NAME(t.[schema_id]),
        TableName = t.[name],
        TableSizeMB = CAST((p.[in_row_used_page_count] + p.[lob_used_page_count] + p.[row_overflow_used_page_count]) * 8.0 / 1024.0 AS DECIMAL(12, 2)),
        p.ROWS
    FROM sys.tables t
    INNER JOIN sys.partitions p ON t.object_id = p.object_id
    WHERE SCHEMA_NAME(t.schema_id) = 'qsh'
      AND p.index_id IN (0, 1)
    ORDER BY (p.[in_row_used_page_count] + p.[lob_used_page_count] + p.[row_overflow_used_page_count]) DESC;

    PRINT 'Total storage used by qsh schema:'
    SELECT TOP 100 PERCENT
        TotalSizeMB = CAST(SUM((p.[in_row_used_page_count] + p.[lob_used_page_count] + p.[row_overflow_used_page_count]) * 8.0 / 1024.0) AS DECIMAL(12, 2)),
        TotalRowCount = SUM(p.[rows])
    FROM sys.tables t
    INNER JOIN sys.partitions p ON t.object_id = p.object_id
    WHERE SCHEMA_NAME(t.schema_id) = 'qsh'
      AND p.index_id IN (0, 1);


END
GO
