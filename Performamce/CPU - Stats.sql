/* ========= Instance CPU Utilization (SQL process) =========
   Returns minute-by-minute SQL CPU %, plus Avg / P95 / Max summary.
*/
DECLARE @minutes int = 30000; -- how far back to look (in minutes)

-- Pull raw scheduler monitor ring buffer
WITH rb AS 
(
    SELECT      DATEADD(ms, -1 * (rb.[timestamp] - si.ms_ticks), GETDATE()) AS EventTime
    ,           CONVERT(xml, rb.record)                                     AS x
    FROM        sys.dm_os_ring_buffers  rb
    CROSS JOIN  sys.dm_os_sys_info      si
    WHERE       rb.ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
    AND         rb.record           LIKE '%<SystemHealth>%'
)
, cpu AS 
(
    SELECT  EventTime
    ,       x.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int')    AS SqlProcessUtilization
    ,       x.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int')            AS SystemIdle            
    FROM    rb
)
, cpu_minute AS 
(
    SELECT  DATEADD(minute, DATEDIFF(minute, 0, EventTime), 0)  AS ts_min
    ,       SqlProcessUtilization                               AS SqlCPU
    FROM    cpu
    WHERE   EventTime >= DATEADD(minute, -@minutes, SYSDATETIME())
)
SELECT  *
INTO    #cpu_minute
FROM    cpu_minute;

-- Minute-by-minute CPU %
SELECT      ts_min      AS [Time (server local)]
,           AVG(SqlCPU) AS [SQL CPU % (avg over minute)]
FROM        #cpu_minute
GROUP BY    ts_min
ORDER BY    ts_min DESC;

-- ===== Summary stats over the same window =====
WITH cpu_series AS 
(
    SELECT  CAST(SqlCPU AS float) AS sql_cpu
    FROM    #cpu_minute 
)
, summary AS
(
    SELECT  AVG(sql_cpu) AS AvgCPU
    ,       MAX(sql_cpu) AS MaxCPU
    FROM    cpu_series
)
SELECT DISTINCT     ROUND(s.AvgCPU, 2) AS AvgCPU
,                   s.MaxCPU
,                   p.P95CPU
FROM                summary s
CROSS JOIN          (
                    SELECT  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sql_cpu) OVER () AS P95CPU
                    FROM    cpu_series
                    ) p;


DROP TABLE #cpu_minute;
