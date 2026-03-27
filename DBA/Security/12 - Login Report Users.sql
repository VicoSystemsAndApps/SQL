
-- Windows Logins -----------------------------
SELECT DISTINCT	
			es.login_name
,			d.name						AS DatabaseName
,			es.host_name
,			es.program_name
,			es.client_interface_name
,			es.status
,			es.cpu_time
,			es.memory_usage
,			es.login_time
,			es.last_request_start_time
,			es.last_request_end_time
FROM		sys.dm_exec_sessions		es
JOIN		sys.databases				d	ON d.database_id = es.database_id
WHERE		es.is_user_process = 1
ORDER BY	es.login_name
,			es.last_request_start_time;

-- AD Has DB Access ----------------------------------
SELECT      l.name					AS LoginName
,           dp.name					AS DBUserName
,           dp.type_desc			AS DBUserType
,           dp.create_date
,           dp.modify_date
,           sp.permission_name
,			sp.state_desc			AS PermissionState
FROM		sys.database_principals		dp
LEFT JOIN	sys.server_principals		l	ON dp.sid			= l.sid
LEFT JOIN	sys.database_permissions	sp	ON dp.principal_id	= sp.grantee_principal_id
WHERE		dp.type IN ('S', 'U', 'G')   -- SQL, Windows user, Windows group
ORDER BY	dp.name;
