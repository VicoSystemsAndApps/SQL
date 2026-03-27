SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @JobName NVARCHAR(200) = 'NAME HERE';

SELECT		j.name													AS JobName
,			msdb.dbo.agent_datetime(h.run_date, h.run_time)			AS RunDateTime
,			CONVERT(VARCHAR, (h.run_duration / 10000)) + 'h ' +  
			CONVERT(VARCHAR, (h.run_duration / 100 % 100)) + 'm ' + 
			CONVERT(VARCHAR, (h.run_duration % 100)) + 's'			AS RunDurationHoursMinsSec
,			CASE	WHEN h.run_Status = 0
						THEN 'Failed'
					WHEN h.run_status = 1
						THEN 'Success'					
					WHEN h.run_status = 2
						THEN 'Retry'
					WHEN h.run_status = 3
						THEN 'Cancelled'
			END														AS RunStatus
FROM		msdb.dbo.sysjobs		j 
JOIN		msdb.dbo.sysjobhistory	h	ON j.job_id = h.job_id 
WHERE		j.[enabled] = 1  --Only Enabled Jobs
--AND			j.name		= @JobName
AND			h.step_id	= 0
ORDER BY	JobName
,			RunDateTime DESC;





