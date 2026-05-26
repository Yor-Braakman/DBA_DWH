-- sp_UpdateStatistics: Update query optimizer statistics
CREATE PROCEDURE [qsh].[sp_UpdateStatistics]
    @TableName NVARCHAR(128) = NULL,
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX)
    DECLARE @statName NVARCHAR(128)
    DECLARE @tblName NVARCHAR(128)
    IF @TableName IS NULL
    BEGIN
        PRINT 'Updating statistics for all tables in qsh schema...'
        
        DECLARE stat_cursor CURSOR FOR
        SELECT s.[name], OBJECT_NAME(s.[object_id])
        FROM sys.[stats] s
        INNER JOIN sys.[objects] o ON s.[object_id] = o.[object_id]
        WHERE o.[schema_id] = SCHEMA_ID('qsh')
          AND o.[type] = 'U'

        OPEN stat_cursor
        FETCH NEXT FROM stat_cursor INTO @statName, @tblName

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = 'UPDATE STATISTICS [qsh].' + QUOTENAME(@tblName) + ' ' + QUOTENAME(@statName)
            PRINT 'Updating: ' + @tblName + '.' + @statName
            IF @DebugMode = 0
                EXEC sp_executesql @SQL
            
            FETCH NEXT FROM stat_cursor INTO @statName, @tblName
        END

        CLOSE stat_cursor
        DEALLOCATE stat_cursor
    END
    ELSE
    BEGIN
        PRINT 'Updating statistics for table: [qsh].' + @TableName
        SET @SQL = 'UPDATE STATISTICS [qsh].' + QUOTENAME(@TableName)
        IF @DebugMode = 0
            EXEC sp_executesql @SQL
    END
END
GO
