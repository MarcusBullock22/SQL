SELECT TOP 100 * 
FROM
(
    SELECT  [Last Execution Time] = last_execution_time,
            [Execution Count] = execution_count,
    [SQL Statement] = (
                    SELECT TOP 1 SUBSTRING (s2. TEXT,statement_start_offset / 2+ 1 ,
    ( ( CASE WHEN statement_end_offset = -1
    THEN ( LEN(CONVERT (NVARCHAR( MAX),s2 .TEXT)) * 2 )
                    ELSE statement_end_offset END )- statement_start_offset) / 2 +1)
                    ),
            [Stored Procedure Name] = COALESCE( OBJECT_NAME(s2 .objectid), 'Ad-Hoc Query'),
            [Last Elapsed Time] = s1.last_elapsed_time,
            [Minimum Elapsed Time] = s1.min_elapsed_time,
            [Maximum Elapsed Time] = s1.max_elapsed_time
    FROM sys.dm_exec_query_stats AS s1
    CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS s2 
) x
WHERE [SQL Statement] NOT LIKE '%SELECT TOP 500%' /* Exclude this query */
ORDER BY [Last Execution Time] DESC