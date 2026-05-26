-- DimQuery: Query details with text and compilation metadata
CREATE VIEW [qsh].[DimQuery] AS
SELECT 
    CONCAT(q.[TenantName], '_', q.[ServerName], '_', q.[DatabaseName], '_', q.[QueryId]) AS QueryDimKey,
    q.[TenantName],
    q.[ServerName],
    q.[DatabaseName],
    q.[QueryId],
    q.[ObjectId],
    qt.[QueryTextContent] AS QueryText,
    qt.[StatementType],
    qt.[QueryHash],
    qt.[QueryPlanHash],
    CASE 
        WHEN q.[ObjectId] > 0 THEN 'Stored Procedure'
        WHEN q.[ObjectId] = 0 THEN 'Ad-hoc Query'
        ELSE 'Unknown'
    END AS QueryType,
    q.[CompilationCount],
    q.[AvgCompileCpuTimeMs],
    q.[MaxCompileCpuTimeMs],
    q.[AvgCompileMemoryMb],
    q.[MaxCompileMemoryMb],
    q.[CompilationStartTime],
    q.[LoadDate]
FROM [qsh].[QueryStoreQuery] q
LEFT JOIN [qsh].[QueryStoreQueryText] qt 
    ON q.[QueryTextId] = qt.[QueryTextId] 
    AND q.[TenantName] = qt.[TenantName] 
    AND q.[ServerName] = qt.[ServerName]
    AND q.[DatabaseName] = qt.[DatabaseName]
GO
