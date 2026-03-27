/* ==== 1) COMPREHENSIVE LOGIN REPORT =======================================
   - Shows server principals, server role membership, disabled flag
   - Last login:
       * SQL 2022+ -> sys.dm_login_stats
       * Else -> current sessions + default trace (if enabled)
=========================================================================== */

SET NOCOUNT ON;

DECLARE @major INT = TRY_CAST(SERVERPROPERTY('ProductMajorVersion') AS INT);

-- 1) Role membership -> temp tables
IF OBJECT_ID('tempdb..#RoleMembers')  IS NOT NULL DROP TABLE #RoleMembers;
IF OBJECT_ID('tempdb..#RolesConcat')  IS NOT NULL DROP TABLE #RolesConcat;

CREATE TABLE #RoleMembers 
(
    PrincipalName SYSNAME NOT NULL
,   ServerRole    SYSNAME NOT NULL
);

INSERT  #RoleMembers
        (PrincipalName, ServerRole)
SELECT  p.name
,       r.name
FROM    sys.server_role_members m
JOIN    sys.server_principals   r ON r.principal_id = m.role_principal_id
JOIN    sys.server_principals   p ON p.principal_id = m.member_principal_id;

CREATE TABLE #RolesConcat 
(
    PrincipalName SYSNAME PRIMARY KEY
,   ServerRoles   NVARCHAR(MAX) NULL
);

INSERT      #RolesConcat
            (PrincipalName, ServerRoles)
SELECT      rm.PrincipalName
,           STUFF((
                   SELECT ',' + rm2.ServerRole
                   FROM #RoleMembers rm2
                   WHERE rm2.PrincipalName = rm.PrincipalName
                   FOR XML PATH(''), TYPE
               ).value('.','nvarchar(max)'), 1, 1, '')
FROM        #RoleMembers rm
GROUP BY    rm.PrincipalName;

-- 2) Default trace last login (safe if disabled)
IF OBJECT_ID('tempdb..#DefaultTrace') IS NOT NULL DROP TABLE #DefaultTrace;
CREATE TABLE #DefaultTrace 
(
    LoginName               SYSNAME PRIMARY KEY
,   LastLoginDefaultTrace   DATETIME
);

DECLARE @tracepath nvarchar(4000) =
(
    SELECT  CONVERT(nvarchar(4000), value)
    FROM    sys.fn_trace_getinfo(NULL)
    WHERE   property = 2
);

IF @tracepath IS NOT NULL
BEGIN
    INSERT      #DefaultTrace 
                (LoginName, LastLoginDefaultTrace)
    SELECT      LoginName
    ,           MAX(StartTime)
    FROM        sys.fn_trace_gettable(@tracepath, DEFAULT)
    WHERE       EventClass = 14  -- Audit Login
    GROUP BY    LoginName;
END

-- 3) Active sessions (approx last login for connected users)
IF OBJECT_ID('tempdb..#ActiveSessions') IS NOT NULL DROP TABLE #ActiveSessions;
CREATE TABLE #ActiveSessions 
(
    LoginName           SYSNAME PRIMARY KEY
,   LastLoginActive     DATETIME
,   HostName            SYSNAME NULL
,   ProgramName         NVARCHAR(256) NULL
,   LastRequestStart    DATETIME NULL
,   LastRequestEnd      DATETIME NULL
);

INSERT      #ActiveSessions 
            (   LoginName
            ,   LastLoginActive
            ,   HostName
            ,   ProgramName
            ,   LastRequestStart
            ,   LastRequestEnd
            )
SELECT      s.login_name
,           MAX(s.login_time)
,           MAX(s.host_name)
,           MAX(s.program_name)
,           MAX(s.last_request_start_time)
,           MAX(s.last_request_end_time)
FROM        sys.dm_exec_sessions s
WHERE       s.is_user_process = 1
GROUP BY    s.login_name;

-- 4) SQL 2022+ login stats (if available)
IF OBJECT_ID('tempdb..#LoginStats') IS NOT NULL DROP TABLE #LoginStats;
CREATE TABLE #LoginStats 
(
    PrincipalName       SYSNAME PRIMARY KEY
,   LastSuccessfulLogin DATETIME NULL
,   LastFailedLogin     DATETIME NULL
);

IF (@major >= 16)
BEGIN
    INSERT  #LoginStats 
            (PrincipalName, LastSuccessfulLogin, LastFailedLogin)
    SELECT  principal_name
    ,       last_successful_login
    ,       last_failed_login
    FROM    sys.dm_login_stats;
END

-- 5) Final report
SELECT      sp.name                                                                         AS principal
,           sp.type_desc                                                                    AS principal_type         -- SQL_LOGIN, WINDOWS_LOGIN, WINDOWS_GROUP
,           act.HostName
,           act.ProgramName
,           sp.is_disabled
,           COALESCE(rc.ServerRoles, '')                                                    AS server_roles
--,           ls.LastSuccessfulLogin                                                          AS last_successful_login_2022
,           dt.LastLoginDefaultTrace
,           act.LastLoginActive
,           COALESCE(ls.LastSuccessfulLogin, dt.LastLoginDefaultTrace, act.LastLoginActive) AS last_login_best_effort
FROM        sys.server_principals   sp
LEFT JOIN   #RolesConcat            rc  ON rc.PrincipalName = sp.name
LEFT JOIN   #LoginStats             ls  ON ls.PrincipalName = sp.name
LEFT JOIN   #DefaultTrace           dt  ON dt.LoginName     = sp.name
LEFT JOIN   #ActiveSessions         act ON act.LoginName    = sp.name
WHERE       sp.type         IN ('S','U','G')      -- SQL, Windows login, Windows group
AND         sp.name         NOT LIKE '##MS_%##'
--AND         sp.principal_id > 2                   -- exclude sa/public-like
AND         sp.type_desc    = 'SQL_LOGIN'
ORDER BY    last_login_best_effort DESC
,           sp.name;
