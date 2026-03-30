/* Script to track progress of SQL Backups and Restores
20250203	jane.palmer		created
*/

SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT 
r.session_id, 
r.blocking_session_id, 
db_name(database_id) AS [DatabaseName],
r.command, 
[SQL_QUERY_TEXT] = Substring(Query.TEXT, (r.statement_start_offset / 2) + 1, (
            (
                CASE r.statement_end_offset
                    WHEN - 1
                        THEN Datalength(Query.TEXT)
                    ELSE r.statement_end_offset
                    END - r.statement_start_offset
                ) / 2
            ) + 1),
                [SP_Name] =COALESCE(Quotename(Db_name(Query.dbid)) + N'.' + Quotename(Object_schema_name(Query.objectid, Query.dbid)) + N'.' + 
     Quotename(Object_name(Query.objectid, Query.dbid)), ''),
r.percent_complete,
start_time,
CONVERT(VARCHAR(20), DATEADD(ms, [estimated_completion_time],
GETDATE()), 20) AS [ETA_COMPLETION_TIME],
CONVERT(NUMERIC(6, 2), r.[total_elapsed_time] / 1000.0 / 60.0) AS [Elapsed_MIN],
CONVERT(NUMERIC(6, 2), r.[estimated_completion_time] / 1000.0 / 60.0) AS [Remaning_ETA_MIN],
CONVERT(NUMERIC(6, 2), r.[estimated_completion_time] / 1000.0 / 60.0/ 60.0) AS [ETA_Hours],
wait_type,
wait_time/1000 AS Wait_Time_Sec, 
wait_resource
FROM sys.dm_exec_requests r 
CROSS APPLY sys.fn_get_sql(r.sql_handle) AS Query WHERE r.session_id>50 AND command IN ('RESTORE DATABASE','BACKUP DATABASE', 'RESTORE LOG', 'BACKUP LOG','DBCC');