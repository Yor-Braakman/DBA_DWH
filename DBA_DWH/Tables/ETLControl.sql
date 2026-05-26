-- ETLControl: Track extraction and loading status per tenant/server/database
-- Primary Key: (TenantName, ServerName, DatabaseName, ETLControlId)
CREATE TABLE [qsh].[ETLControl] (
    [ETLControlId] INT NOT NULL IDENTITY(1,1),
    [TenantName] NVARCHAR(128) NOT NULL,
    [ServerName] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL,
    [LastExtractTime] DATETIME2(7) NOT NULL,
    [ExtractDurationSeconds] INT NOT NULL,
    [RecordsInserted] BIGINT NOT NULL,
    [RecordsUpdated] BIGINT NOT NULL,
    [ExtractStatus] NVARCHAR(50) NOT NULL,
    [ErrorMessage] NVARCHAR(MAX) NULL,
    [LoadDate] DATETIME2(7) NOT NULL DEFAULT GETUTC(),
    CONSTRAINT [PK_ETLControl] PRIMARY KEY CLUSTERED 
        ([TenantName] ASC, [ServerName] ASC, [DatabaseName] ASC, [ETLControlId] ASC)
)
GO

-- Index for finding latest extract per tenant/server/database
CREATE NONCLUSTERED INDEX [IX_ETLControl_Latest]
    ON [qsh].[ETLControl]([TenantName], [ServerName], [DatabaseName], [LastExtractTime] DESC)
    INCLUDE ([ExtractStatus], [RecordsInserted], [RecordsUpdated])
GO

CREATE NONCLUSTERED INDEX [IX_ETLControl_Status]
    ON [qsh].[ETLControl]([ExtractStatus], [LastExtractTime] DESC)
    INCLUDE ([TenantName], [ServerName], [DatabaseName])
GO
