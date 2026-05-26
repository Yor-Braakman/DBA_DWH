-- sp_MERGE_QueryStoreWaitStats: UPDATE/INSERT pattern for wait statistics
CREATE PROCEDURE [qsh].[sp_MERGE_QueryStoreWaitStats]
    @TenantName NVARCHAR(128),
    @ServerName NVARCHAR(128),
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @recordsInserted INT = 0
    DECLARE @recordsUpdated INT = 0

    BEGIN TRANSACTION

    -- UPDATE existing wait statistics
    UPDATE tgt
    SET tgt.[TotalWaitTimeMs] = src.[TotalWaitTimeMs],
        tgt.[AvgWaitTimeMs] = src.[AvgWaitTimeMs],
        tgt.[MaxWaitTimeMs] = src.[MaxWaitTimeMs],
        tgt.[CountWaits] = src.[CountWaits]
    FROM [qsh].[QueryStoreWaitStats] tgt
    INNER JOIN [qsh].[QueryStoreWaitStats] src
        ON tgt.[TenantName] = src.[TenantName]
        AND tgt.[ServerName] = src.[ServerName]
        AND tgt.[DatabaseName] = src.[DatabaseName]
        AND tgt.[RuntimeStatsIntervalId] = src.[RuntimeStatsIntervalId]
        AND tgt.[QueryId] = src.[QueryId]
        AND tgt.[PlanId] = src.[PlanId]
        AND tgt.[WaitCategory] = src.[WaitCategory]
    WHERE tgt.[TenantName] = @TenantName 
      AND tgt.[ServerName] = @ServerName
      AND tgt.[DatabaseName] = @DatabaseName

    SET @recordsUpdated = @@ROWCOUNT

    -- INSERT new wait statistics (those that don't exist yet)
    INSERT INTO [qsh].[QueryStoreWaitStats] (
        [TenantName], [ServerName], [DatabaseName], [RuntimeStatsIntervalId],
        [QueryId], [PlanId], [WaitCategory], [WaitCategoryId],
        [TotalWaitTimeMs], [AvgWaitTimeMs], [MaxWaitTimeMs],
        [QueryWaitTimeCategory], [CountWaits]
    )
    SELECT 
        src.[TenantName], src.[ServerName], src.[DatabaseName], src.[RuntimeStatsIntervalId],
        src.[QueryId], src.[PlanId], src.[WaitCategory], src.[WaitCategoryId],
        src.[TotalWaitTimeMs], src.[AvgWaitTimeMs], src.[MaxWaitTimeMs],
        src.[QueryWaitTimeCategory], src.[CountWaits]
    FROM [qsh].[QueryStoreWaitStats] src
    WHERE src.[TenantName] = @TenantName 
      AND src.[ServerName] = @ServerName
      AND src.[DatabaseName] = @DatabaseName
      AND NOT EXISTS (
          SELECT 1
          FROM [qsh].[QueryStoreWaitStats] tgt
          WHERE tgt.[TenantName] = src.[TenantName]
            AND tgt.[ServerName] = src.[ServerName]
            AND tgt.[DatabaseName] = src.[DatabaseName]
            AND tgt.[RuntimeStatsIntervalId] = src.[RuntimeStatsIntervalId]
            AND tgt.[QueryId] = src.[QueryId]
            AND tgt.[PlanId] = src.[PlanId]
            AND tgt.[WaitCategory] = src.[WaitCategory]
      )

    SET @recordsInserted = @@ROWCOUNT

    COMMIT TRANSACTION

    -- Log results
    INSERT INTO [qsh].[ETLControl] (
        [TenantName], [ServerName], [DatabaseName],
        [LastExtractTime], [ExtractDurationSeconds],
        [RecordsInserted], [RecordsUpdated], [ExtractStatus]
    )
    VALUES (
        @TenantName, @ServerName, @DatabaseName,
        GETUTC(), 0,
        @recordsInserted, @recordsUpdated, 'SUCCESS'
    )

    SELECT @recordsInserted AS RecordsInserted, @recordsUpdated AS RecordsUpdated

END
GO
