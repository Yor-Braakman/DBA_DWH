-- DimInterval: Time intervals for aggregation
CREATE VIEW [qsh].[DimInterval] AS
SELECT 
    [RuntimeStatsIntervalId],
    [TenantName],
    [ServerName],
    [IntervalStartTime],
    [IntervalEndTime],
    [IntervalDurationMinutes],
    CAST([IntervalStartTime] AS DATE) AS IntervalDate,
    DATENAME(HOUR, [IntervalStartTime]) + ':' + 
        RIGHT('00' + DATENAME(MINUTE, [IntervalStartTime]), 2) AS IntervalTimeOfDay,
    DATENAME(WEEKDAY, [IntervalStartTime]) AS IntervalDayOfWeek,
    [LoadDate]
FROM [qsh].[RuntimeStatsInterval]
GO
