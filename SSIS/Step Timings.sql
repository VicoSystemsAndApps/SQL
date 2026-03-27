USE SSISDB;

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- User for @SSIS
--SELECT	DISTINCT project_name
--FROM	SSISDB.[catalog].executions;

DECLARE @DATE		DATE			= GETDATE()
,		@SSIS		VARCHAR(500)	= 'CRM_Email_Alerts'
,		@ExecPath	VARCHAR(1000)	= 'Process_Email_Alert_History';



SELECT		e.folder_name
,			e.project_name
,			e.package_name
,			SUBSTRING(es.execution_path, LEN(e.package_name) - 3, LEN(es.execution_path))	AS ExecutionPath
,			MAX(DATEDIFF(minute, es.start_time, es.end_time))								AS MAXexecution_time
,			AVG(DATEDIFF(minute, es.start_time, es.end_time))								AS AVGexecution_time
FROM		SSISDB.[catalog].executions				e
JOIN		SSISDB.[catalog].executable_statistics	es	ON e.execution_id = es.execution_id
WHERE		1 = 1
AND			e.project_name		= @SSIS
AND			es.execution_path	LIKE '%' + @ExecPath + '%'
GROUP BY	e.folder_name
,			e.project_name
,			e.package_name
,			SUBSTRING(es.execution_path, LEN(e.package_name) - 3, LEN(es.execution_path))
ORDER BY	MAXexecution_time DESC;



SELECT  e.folder_name
,		e.project_name
,		e.package_name
,		SUBSTRING(es.execution_path, LEN(e.package_name) - 3, LEN(es.execution_path)) AS ExecutionPath
,		DATEDIFF(minute, es.start_time, es.end_time) AS execution_time
FROM	SSISDB.[catalog].executions				e
JOIN	SSISDB.[catalog].executable_statistics	es	ON e.execution_id = es.execution_id
WHERE	e.start_time		>= @DATE
AND		e.project_name		= @SSIS
AND		es.execution_path	LIKE '%' + @ExecPath + '%'
ORDER BY execution_time DESC;
/*

SELECT		OPR.object_name
,			CASE message_source_type
                WHEN 10 THEN 'Entry APIs, such as T-SQL and CLR Stored procedures'
                WHEN 20 THEN 'External process used to run package (ISServerExec.exe)'
                WHEN 30 THEN 'Package-level objects'
                WHEN 40 THEN 'Control Flow tasks'
                WHEN 50 THEN 'Control Flow containers'
                WHEN 60 THEN 'Data Flow task'
            END												AS message_source_type
,			CAST(start_time AS datetime)					AS start_time
,			message
,			LEFT(message, CHARINDEX(':', message) -1)		AS Block
,			CONVERT(TIME(0), LEFT(RIGHT(message, 13),12))	AS execution_time
FROM        SSISDB.[catalog].operation_messages	MSG
JOIN		SSISDB.[catalog].operations			OPR	ON OPR.operation_id = MSG.operation_id
WHERE		start_time			> @DATE 
AND			message				LIKE '%:Finish%' 
AND			message				NOT LIKE 'INSERT Record SQL Task:Finished%'
AND			message_source_type NOT IN (30, 50)
AND			OPR.object_name		= @SSIS
ORDER BY execution_time DESC

*/