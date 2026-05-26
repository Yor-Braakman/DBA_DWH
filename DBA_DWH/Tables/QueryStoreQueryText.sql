-- QueryStoreQueryText: Actual T-SQL query text
-- Primary Key: (TenantName, ServerName, DatabaseName, QueryTextId) for multi-tenant granularity
CREATE TABLE [qsh].[QueryStoreQueryText] (
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [QueryTextId] BIGINT NOT NULL,
    [QueryTextContent] NVARCHAR(MAX) NOT NULL,
    [StatementType] NVARCHAR(128) NULL,
    [QueryHash] BINARY(8) NULL,
    [QueryPlanHash] BINARY(8) NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT [PK_QueryStoreQueryText] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [QueryTextId] ASC)
)
GO

-- Supporting indexes
CREATE NONCLUSTERED INDEX [IX_QueryStoreQueryText_Hash]
    ON [qsh].[QueryStoreQueryText]([QueryHash], [QueryPlanHash])
    INCLUDE ([QueryTextId])
GO
