USE SSISDB;

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--DECLARE @DATE DATE = GETDATE() 

--SELECT		e.folder_name
--,			e.project_name
--,			e.package_name
--,			es.execution_path
--,			DATEDIFF(minute, es.start_time, es.end_time) AS 'execution_time[min]'
--FROM		[catalog].executions				e
--JOIN		[catalog].executable_statistics	es	ON e.execution_id = es.execution_id
--WHERE		e.start_time >= @DATE
--AND			e.project_name = 'satsuma.etl'
--AND			DATEDIFF(minute, es.start_time, es.end_time) > 5
--ORDER BY	DATEDIFF(minute, es.start_time, es.end_time) DESC




SELECT		em.package_name 
,			em.message_source_name  
,			MIN(em.message_time)											AS Task_Start
,			MAX(em.message_time)											AS Task_Finish
,			DATEDIFF(MINUTE, MIN(em.message_time), MAX(em.message_time))	AS Duration_Mins
FROM		[catalog].event_messages	em
JOIN		[catalog].operations		o	ON o.operation_id = em.operation_id
WHERE		CONVERT(DATE, em.message_time)	>= GETDATE()-1
--AND			o.object_name					= 'Satsuma.etl'
AND			em.message_source_type			< 60 -- Data Flow
AND			em.event_name					IN ('OnPreExecute', 'OnPostExecute')
AND			em.message_source_name			!= 'WriteEvent'
AND			em.message_source_name			NOT LIKE 'SEQC%'
AND			LEFT(em.package_name, LEN(em.package_name) -5) != em.message_source_name
GROUP BY	em.operation_id 
,			em.package_name 
,			em.message_source_name 
HAVING		DATEDIFF(MINUTE, MIN(em.message_time), MAX(em.message_time)) > 15
ORDER BY	Duration_Mins DESC



SELECT		em.*
FROM		[catalog].event_messages	em
JOIN		[catalog].operations		o	ON	o.operation_id = em.operation_id
WHERE		CONVERT(DATE, em.message_time)	>= GETDATE()-1
--AND			o.object_name					= 'Satsuma.etl'
AND			em.message_source_type			= 40 -- Data Flow
AND			em.event_name					IN ('OnPreExecute', 'OnPostExecute')
--AND			em.package_name					= 'Interface_DimAgreement.dtsx'
--AND			em.message_source_name			= 'SQL - Get Final RowCount'
