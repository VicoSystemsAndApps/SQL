/*
1. CPU Usage – Find Peak / Average Consumption

    This shows CPU % used by SQL Server over time.
    If SQLProcessUtilization frequently exceeds 60–70% - we'll need higher Azure SKU's
*/

SELECT TOP 50   record.value('(./Record/@time)[1]', 'bigint')                                               AS TimeStampRaw
,               record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')          AS SystemIdle
,               record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int')  AS SQLProcessUtilization
,               100 - record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')    AS TotalCPU
FROM            (
                SELECT  CAST(record AS XML) AS record
                FROM    sys.dm_os_ring_buffers
                WHERE   ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
                ) rb
ORDER BY        TimeStampRaw DESC;


/*
2. IO Workload – Read/Write Throughput & Latency

    IO is critical when choosing GP vs Business Critical.
    Latency > 20–30ms = IO bottlenecks → GP is fine since Azure storage gives ~5–10ms typical.

    Very IO-heavy systems might justify Business Critical (local SSD).

*/
SELECT      DB_NAME(vfs.database_id)                                AS DatabaseName
,           vfs.num_of_reads
,           vfs.num_of_writes
,           vfs.io_stall_read_ms
,           vfs.io_stall_write_ms
,           (vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads,0))     AS AvgReadLatency_ms
,           (vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes,0))   AS AvgWriteLatency_ms
FROM        sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
WHERE       DB_NAME(vfs.database_id) IN ('SDSProValWorking', 'SDSSequelWorking')
ORDER BY    AvgReadLatency_ms DESC;

/*

3. Memory Pressure – Page Life Expectancy

    Shows buffer pool pressure.
    PLE > 300 sec ⇒ memory OK.
    PLE < 100 sec frequently ⇒ memory pressure → consider more vCores (because memory scales with vCores).

*/
SELECT  counter_name
,       cntr_value AS PLE
FROM    sys.dm_os_performance_counters
WHERE   counter_name = 'Page life expectancy';


/*
4. Top CPU Queries (Most Important for Sizing)

    This tells us which queries eat the most CPU.
    If you see a few queries dominating CPU, scaling the whole SQL tier might be unnecessary — they might just need indexing/tuning.
*/

SELECT TOP 20   qs.total_worker_time / 1000                         AS TotalCPU_ms
,               qs.execution_count
,               qs.total_worker_time / qs.execution_count / 1000    AS AvgCPU_ms
,               qs.total_logical_reads                              AS TotalReads
,               qs.total_logical_writes                             AS TotalWrites
,               DB_NAME(qp.dbid)                                    AS DatabaseName
,               SUBSTRING(qt.text, qs.statement_start_offset/2
                ,   (CASE WHEN qs.statement_end_offset = -1 
                        THEN LEN(qt.text) * 2 
                        ELSE qs.statement_end_offset 
                    END - qs.statement_start_offset)/2)             AS QueryText
FROM            sys.dm_exec_query_stats                 qs
CROSS APPLY     sys.dm_exec_sql_text(qs.sql_handle)     qt
CROSS APPLY     sys.dm_exec_query_plan(qs.plan_handle)  qp
ORDER BY        qs.total_worker_time DESC;

/*
5. Instance DG Stats – Batch Requests per Second

    This is the classic measure of how “busy” an OLTP SQL Server really is.
    < 500 batch/sec → 2–4 vCores usually enough
    500–2000 batch/sec → 4–8 vCores
    > 2000 batch/sec → Business Critical or MI high vCore needed
*/
SELECT  cntr_value AS BatchRequestsPerSecond
FROM    sys.dm_os_performance_counters
WHERE   counter_name = 'Batch Requests/sec';


/*
6. Wait Stats – Determine Real Bottlenecks

    Shows whether performance bottlenecks are CPU, memory, IO, or locking.
    SOS_SCHEDULER_YIELD = CPU pressure
    PAGEIOLATCH_* = slow storage
    WRITELOG = log IO bottleneck
    LCK_* = blocking / concurrency issues
    CXPACKET = parallelism (can be normal)
*/
SELECT TOP 20   wait_type
,               wait_time_ms
,               signal_wait_time_ms
,               wait_time_ms - signal_wait_time_ms AS resource_wait_ms
FROM            sys.dm_os_wait_stats
ORDER BY        wait_time_ms DESC;

