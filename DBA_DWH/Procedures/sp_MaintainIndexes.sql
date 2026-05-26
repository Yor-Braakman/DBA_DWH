-- sp_MaintainIndexes: Index maintenance (reorganize/rebuild) with fragmentation analysis
CREATE PROCEDURE [qsh].[sp_MaintainIndexes]
    @FragmentationThreshold FLOAT = 10.0,
    @RebuildThreshold FLOAT = 30.0,
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tableName NVARCHAR(128)
    DECLARE @indexName NVARCHAR(128)
    DECLARE @fragmentation FLOAT
    DECLARE @pageCount BIGINT
    DECLARE @SQL NVARCHAR(MAX)

    PRINT 'Index Maintenance Report'
    PRINT 'Fragmentation Threshold (REORGANIZE): ' + CAST(@FragmentationThreshold AS VARCHAR(5)) + '%'
    PRINT 'Rebuild Threshold: ' + CAST(@RebuildThreshold AS VARCHAR(5)) + '%'

    CREATE TABLE #IndexFragmentation (
        TableName NVARCHAR(128),
        IndexName NVARCHAR(128),
        Fragmentation FLOAT,
        PageCount BIGINT,
        Action NVARCHAR(50)
    )

    INSERT INTO #IndexFragmentation
    SELECT 
        OBJECT_NAME(ips.[object_id]),
        i.[name],
        ips.[avg_fragmentation_in_percent],
        ips.[page_count],
        CASE 
            WHEN ips.[avg_fragmentation_in_percent] < @FragmentationThreshold THEN 'NONE'
            WHEN ips.[avg_fragmentation_in_percent] <= @RebuildThreshold THEN 'REORGANIZE'
            ELSE 'REBUILD'
        END
    FROM sys.[dm_db_index_physical_stats](DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.[indexes] i ON ips.[object_id] = i.[object_id] 
        AND ips.[index_id] = i.[index_id]
    WHERE ips.[page_count] > 1000
      AND ips.[avg_fragmentation_in_percent] > @FragmentationThreshold
      AND OBJECTPROPERTY(ips.[object_id], 'IsUserTable') = 1
      AND OBJECT_NAME(ips.[object_id]) NOT IN ('sysdiagrams')

    -- Display fragmentation report
    SELECT * FROM #IndexFragmentation ORDER BY Fragmentation DESC
    PRINT ''
    PRINT 'Total indexes requiring maintenance: ' + CAST((SELECT COUNT(*) FROM #IndexFragmentation WHERE Action <> 'NONE') AS VARCHAR(5))
    PRINT ''

    -- Execute maintenance operations
    DECLARE index_cursor CURSOR FOR
    SELECT TableName, IndexName, Action FROM #IndexFragmentation WHERE Action <> 'NONE'

    OPEN index_cursor
    FETCH NEXT FROM index_cursor INTO @tableName, @indexName, @SQL

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @SQL = 'REORGANIZE'
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@indexName) + ' ON [qsh].' + QUOTENAME(@tableName) + ' REORGANIZE'
            PRINT 'Reorganizing: ' + @tableName + '.' + @indexName
            IF @DebugMode = 0
                EXEC sp_executesql @SQL
        END
        ELSE IF @SQL = 'REBUILD'
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@indexName) + ' ON [qsh].' + QUOTENAME(@tableName) + ' REBUILD'
            PRINT 'Rebuilding: ' + @tableName + '.' + @indexName
            IF @DebugMode = 0
                EXEC sp_executesql @SQL
        END

        FETCH NEXT FROM index_cursor INTO @tableName, @indexName, @SQL
    END

    CLOSE index_cursor
    DEALLOCATE index_cursor

    DROP TABLE #IndexFragmentation

    PRINT 'Index maintenance completed'

END
GO
