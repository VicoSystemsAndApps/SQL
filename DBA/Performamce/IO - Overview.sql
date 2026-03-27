/*
File-level IO latency

Rule of thumb:
    Reads > 20 ms → IO subsystem might be struggling.
    Writes > 5 ms → potential log file / storage issue.
*/

-- Stats after this can be worked out from restart date
SELECT  sqlserver_start_time AS LastServerRestart
FROM    sys.dm_os_sys_info;


SELECT      DB_NAME(vfs.database_id)                            AS DatabaseName
,           mf.name                                             AS LogicalName
,           mf.type_desc
,           FORMAT(vfs.num_of_reads, 'N0')                      AS num_of_reads
,           FORMAT(vfs.num_of_writes, 'N0')                     AS num_of_writes
,           vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads,0)   AS AvgReadLatency_ms
,           vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes,0) AS AvgWriteLatency_ms
FROM        sys.dm_io_virtual_file_stats(NULL, NULL)    vfs
JOIN        sys.master_files                            mf  ON  vfs.database_id = mf.database_id 
                                                            AND vfs.file_id     = mf.file_id
WHERE       vfs.database_id > 4
AND 	    DB_NAME(vfs.database_id) NOT IN ('SQLMaint', 'DBAMaint')   
ORDER BY    DB_NAME(vfs.database_id);

-- Top queries by physical IO
-- Shows the "heaviest" queries on disk.
SELECT TOP 20   FORMAT(qs.total_physical_reads, 'N0')                           AS total_physical_reads
,               FORMAT(qs.total_logical_reads, 'N0')                            AS total_logical_reads
,               FORMAT(qs.total_logical_writes, 'N0')                           AS total_logical_writes
,               FORMAT(qs.execution_count, 'N0')                                AS execution_count
,               FORMAT(qs.total_elapsed_time / qs.execution_count, 'N0')        AS AvgElapsedTime_ms
,               SUBSTRING(qt.text, (qs.statement_start_offset/2) + 1,
                    ((IIF(qs.statement_end_offset = -1
                    , DATALENGTH(qt.text)
                    , qs.statement_end_offset) - qs.statement_start_offset)
                / 2) + 1)                                                       AS QueryText
FROM            sys.dm_exec_query_stats             qs
CROSS APPLY     sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY        qs.total_physical_reads DESC;
