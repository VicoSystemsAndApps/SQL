USE SSISDB;

SELECT TOP 200	e.execution_id
,				e.folder_name
,				e.project_name
,				e.package_name
,				e.start_time
,				e.end_time
,				e.status
,				m.message_time
,				m.message
FROM			catalog.event_messages m
JOIN			catalog.executions     e	ON m.operation_id = e.execution_id
WHERE			e.start_time		> DATEADD(DAY, -30, SYSUTCDATETIME())
AND				e.status			= 4                -- Failed
AND				m.message_type		= 120        -- Error
ORDER BY		e.start_time DESC
,				m.message_time DESC;