USE msdb;
GO

WITH base AS 
            (
            SELECT  j.name                                  AS JobName
            ,       h.run_status
            ,       h.run_duration
            ,       (h.run_duration / 10000) * 3600
                    + ((h.run_duration / 100) % 100) * 60
                    + (h.run_duration % 100)                AS duration_seconds
            FROM    msdb.dbo.sysjobs        j
            JOIN    msdb.dbo.sysjobhistory  h   ON j.job_id = h.job_id
            WHERE   j.enabled = 1        -- only enabled jobs
            AND     h.step_id = 0        -- job outcome row
            )
SELECT      s.JobName
,           CONCAT(
                    CAST(s.avg_secs / 3600 AS varchar(10)), 'h ',
                    RIGHT('00' + CAST((s.avg_secs % 3600) / 60 AS varchar(2)), 2), 'm ',
                    RIGHT('00' + CAST((s.avg_secs % 60) AS varchar(2)), 2), 's'
            )       AS AvgRunDuration
,           s.cnt1  AS [Count Succeeded]
,           s.cnt2  AS [Count Retry]
,           s.cnt3  AS [Count Canceled]
FROM        (
            SELECT      JobName
            ,           CAST(ROUND(AVG(CAST(duration_seconds AS float)), 0) AS int) AS avg_secs
            ,           SUM(CASE WHEN run_status = 1 THEN 1 ELSE 0 END)             AS cnt1
            ,           SUM(CASE WHEN run_status = 2 THEN 1 ELSE 0 END)             AS cnt2
            ,           SUM(CASE WHEN run_status = 3 THEN 1 ELSE 0 END)             AS cnt3
            FROM base
            GROUP BY JobName
            ) AS s
ORDER BY s.JobName;
