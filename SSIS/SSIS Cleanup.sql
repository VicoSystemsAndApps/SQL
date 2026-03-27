USE msdb;
GO
SELECT j.name, j.enabled, js.last_run_outcome, js.last_run_date, js.last_run_time
FROM sysjobs j
JOIN sysjobservers js ON j.job_id = js.job_id
WHERE j.name LIKE '%SSIS Server Maintenance Job%';