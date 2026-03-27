USE msdb;
GO

WITH JobExecutions AS 
(	
SELECT		j.job_id
,			j.name																		AS job_name
,			COUNT(h.instance_id)														AS total_executions
,			DATEDIFF(DAY, MIN(CONVERT(DATETIME, CONVERT(CHAR(8), h.run_date), 112))
			, MAX(CONVERT(DATETIME, CONVERT(CHAR(8), h.run_date), 112))
			) + 1																		AS days_span
,			CASE WHEN DATEDIFF(DAY, MIN(CONVERT(DATETIME, CONVERT(CHAR(8), h.run_date), 112)), MAX(CONVERT(DATETIME, CONVERT(CHAR(8), h.run_date), 112))) = 0
				THEN COUNT(h.instance_id)
				ELSE COUNT(h.instance_id) * 1.0 / NULLIF(DATEDIFF(DAY, MIN(CONVERT(DATETIME, CONVERT(CHAR(8), h.run_date), 112)), MAX(CONVERT(DATETIME, CONVERT(CHAR(8), h.run_date), 112))), 0)
			END																			AS avg_executions_per_day
FROM		sysjobs j
LEFT JOIN	sysjobhistory h ON	j.job_id	= h.job_id
							AND h.step_id	= 0
GROUP BY	j.job_id
,			j.name
)
SELECT	*
,		CEILING(avg_executions_per_day * 30.0) AS suggested_rows_per_job_30d
INTO	#SuggestedRetention
FROM	JobExecutions;

SELECT		job_name
,			total_executions
,			days_span
,			ROUND(avg_executions_per_day, 2) AS avg_executions_per_day
,			suggested_rows_per_job_30d
FROM		#SuggestedRetention
ORDER BY	suggested_rows_per_job_30d DESC;

PRINT '--- CONFIGURATION RECOMMENDATION ---';

DECLARE @total_jobs		INT
,		@total_rows		INT
,		@category		NVARCHAR(100)
,		@rows_per_job	INT
,		@total_limit	INT;

SELECT	@total_jobs = COUNT(*)
,		@total_rows = SUM(suggested_rows_per_job_30d)
FROM	#SuggestedRetention;

IF @total_jobs < 20
BEGIN
	SET @category = 'Light workload server (< 20 jobs)';
	SET @rows_per_job = 1000;
	SET @total_limit = 10000;
END
ELSE IF @total_rows <= 50000
BEGIN
	SET @category = 'Moderate workload (frequent jobs or many jobs)';
	SET @rows_per_job = 5000;
	SET @total_limit = 50000;
END
ELSE
BEGIN
	SET @category = 'Critical workload (long retention recommended)';
	SET @rows_per_job = 10000;
	SET @total_limit = 100000;
END

SELECT	@category		AS workload_category
,		@total_jobs		AS total_jobs
,		@total_rows		AS estimated_total_rows_for_30_days
,		@rows_per_job	AS recommended_rows_per_job
,		@total_limit	AS recommended_global_limit;

DROP TABLE #SuggestedRetention;