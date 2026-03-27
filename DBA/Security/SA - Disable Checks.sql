
-- App using SA
SELECT	session_id
,		login_name
,		host_name
,		program_name
FROM	sys.dm_exec_sessions
WHERE	login_name = 'sa';


-- SQL Agent using SA
SELECT	sj.name
,		sjs.step_id
,		sjs.command
FROM	msdb.dbo.sysjobs		sj
JOIN	msdb.dbo.sysjobsteps	sjs ON sj.job_id = sjs.job_id
WHERE	sjs.command		LIKE '%sa%' 
OR		sjs.proxy_id	= 0;


-- WE have another sysadmin account. If we don't we can't disable!
SELECT	name
,		type_desc
,		is_disabled
FROM	sys.server_principals
WHERE	IS_SRVROLEMEMBER('sysadmin', name) = 1;


-- SQL Server Auth Mode. Windows only, trivial to disable, mixed - double check everything
-- 2 = Windows, 1 or 0 = SQL
EXEC xp_instance_regread 
        N'HKEY_LOCAL_MACHINE'
    ,   N'Software\Microsoft\MSSQLServer\MSSQLServer'
    ,   N'LoginMode';


-- Hardcoded References in SSIS, Linked Server etc
SELECT  name
,       uses_self_credential
,       remote_name
FROM    sys.servers         s
JOIN    sys.linked_logins   ll ON s.server_id = ll.server_id
WHERE   ll.remote_name = 'sa';

