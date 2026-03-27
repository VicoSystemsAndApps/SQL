DECLARE @WindowsLogin   SYSNAME = N'AD\Group'
,       @cmd            NVARCHAR(MAX);

-- Active Sessions ------------------------------------------
SELECT  s.session_id
,       s.login_name
,       s.host_name
,       s.program_name
,       s.status
,       s.last_request_start_time
,		s.last_request_end_time
FROM	sys.dm_exec_sessions s
WHERE	s.login_name = @WindowsLogin;

-- SQL Agent Jobs -------------------------------------
SELECT  j.job_id
,       j.name AS JobName
,		l.name AS JobOwner
FROM	msdb.dbo.sysjobs		j
JOIN	sys.server_principals	l ON j.owner_sid = l.sid
WHERE	l.name = @WindowsLogin;

-- Proxy Credential ------------------------------------
SELECT  p.proxy_id
,       p.name AS ProxyName
,		c.credential_identity
FROM	msdb.dbo.sysproxies p
JOIN	sys.credentials		c ON p.credential_id = c.credential_id
WHERE	c.credential_identity = @WindowsLogin;

-- Any mappings to User Databases -----------------------------

SET @cmd = '
    SELECT      ''?'' AS DatabaseName
    ,           dp.name AS UserName
    ,           dp.type_desc AS UserType
    FROM        [?].sys.database_principals dp
    WHERE       dp.sid = SUSER_SID(''' + @windowsLogin + ''')
    ORDER BY    dp.name;
    ';

EXEC sp_msforeachdb @cmd;

-- Linked Servers ----------------------------------------------------
SELECT  s.name AS LinkedServer
,       sp.uses_self_credential
,       sp.remote_name
FROM    sys.linked_logins sp
JOIN    sys.servers s ON sp.server_id = s.server_id
WHERE   sp.local_principal_id = SUSER_SID(@WindowsLogin);


-- Own Schemas or Objects? ---------------------------------------
SELECT  s.name AS SchemaName
FROM    sys.schemas s
WHERE   s.principal_id = SUSER_SID(@WindowsLogin);


-- Credentials used by any proxies? e.g. backup devices ------------
SELECT  credential_id
,       name
,       credential_identity
FROM    sys.credentials
WHERE   credential_identity = @WindowsLogin;
