SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @RunDate	INT = 20220101
,		@JobName	NVARCHAR(200) = 'NAME HERE';

SELECT		j.name									AS JobName
,			s.step_id								AS Step
,			s.step_name								AS StepName
,			MIN((h.run_duration / 10000 * 3600 + 
				(run_duration / 100) % 100 * 60 + 
				run_duration%100 + 31 ) / 60)		AS LowestMin
,			AVG((h.run_duration / 10000 * 3600 + 
				(run_duration / 100) % 100 * 60 + 
				run_duration % 100 + 31 ) / 60)		AS AverageMin
,			MAX((h.run_duration / 10000 * 3600 + 
				(run_duration / 100) % 100 * 60 + 
				run_duration % 100 + 31 ) / 60)		AS HighestMin
,			CONVERT(DECIMAL(5,2), STDEV((h.run_duration / 10000 * 3600 + 
				(run_duration / 100) % 100 * 60 + 
				run_duration%100 + 31 ) / 60))		AS stdevMin
FROM		msdb.dbo.sysjobs		j 
JOIN		msdb.dbo.sysjobsteps	s	ON j.job_id		= s.job_id
JOIN		msdb.dbo.sysjobhistory	h	ON s.job_id		= h.job_id 
										AND s.step_id	= h.step_id 
										AND h.step_id	!= 0
WHERE		j.enabled		= 1   
AND			j.name			= @JobName
AND			h.run_date		>= @RunDate
GROUP BY	j.Name, s.step_id, s.step_name
ORDER BY	Step ASC;



