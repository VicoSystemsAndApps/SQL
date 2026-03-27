SELECT @@VERSION;
-- By DB overview---------------------------------------

EXEC sp_msforeachdb '
USE [?];

SELECT
    DB_NAME() AS database_name,
    pr.name AS principal_name,
    pr.type_desc,
    pe.class_desc,
    pe.permission_name,
    pe.state_desc
FROM sys.database_permissions pe
JOIN sys.database_principals pr
    ON pe.grantee_principal_id = pr.principal_id
WHERE pr.type IN (''S'')
AND DB_NAME() NOT IN (''master'', ''msdb'', ''model'', ''tempdb'', ''dbamaint'', ''sqlmaint'')
ORDER BY pr.name, pe.permission_name;
';


-- Linked Servers -------------------------------------------------
SELECT      s.name                      AS linked_server
,           sp_local.name               AS local_login
,           CASE    WHEN ll.uses_self_credential = 1 THEN 'SELF (uses current security context)'
                    ELSE 'EXPLICIT (remote login name not exposed in SQL 2016 catalog views)'
            END                         AS login_mapping_type
,           ll.modify_date
FROM        sys.linked_logins       ll
JOIN        sys.servers             s           ON ll.server_id             = s.server_id
LEFT JOIN   sys.server_principals   sp_local    ON ll.local_principal_id    = sp_local.principal_id
WHERE       s.is_linked     = 1
AND         sp_local.name   IS NOT NULL
ORDER BY    s.name
,           sp_local.name;


-- Linked Servers and Credentials
SELECT      s.name          AS linked_server
,           c.credential_id
,           c.name          AS credential_name
FROM        sys.credentials             c
LEFT JOIN   sys.external_data_sources   eds ON c.credential_id  = eds.credential_id
LEFT JOIN   sys.servers                 s   ON s.name           = eds.name;


-- Agent Jobs --------------------------------------------------------
SELECT      j.job_id
,           j.name AS job_name
,           sp.name AS job_owner
FROM        msdb.dbo.sysjobs j
LEFT JOIN   sys.server_principals sp ON j.owner_sid = sp.sid
WHERE       sp.name  != 'sa'
ORDER BY    sp.name
,           j.name;


-- Run under a proxy -------------------------------------------------
SELECT      j.name AS job_name
,           s.step_id
,           s.step_name
,           s.subsystem
,           s.proxy_id
,           p.name AS proxy_name
FROM        msdb.dbo.sysjobsteps    s
JOIN        msdb.dbo.sysjobs        j ON j.job_id   = s.job_id
LEFT JOIN   msdb.dbo.sysproxies     p ON s.proxy_id = p.proxy_id
WHERE       p.name IS NOT NULL
ORDER BY    j.name
,           s.step_id;

-- Credentials (Server level) ----------------------------------------
SELECT      sp.name AS login_name
,           c.name AS credential_name
FROM        sys.server_principals   sp
LEFT JOIN   sys.credentials         c ON sp.credential_id = c.credential_id
ORDER BY    login_name;


-- Endpoints ----------------------------------------------------
SELECT      ep.endpoint_id
,           ep.name                 AS endpoint_name
,           ep.type_desc
,           pr.name                 AS grantee
,           pe.permission_name
,           pe.state_desc
FROM        sys.server_permissions  pe
JOIN        sys.endpoints           ep ON pe.major_id               = ep.endpoint_id
JOIN        sys.server_principals   pr ON pe.grantee_principal_id   = pr.principal_id
ORDER BY    ep.name
,           pr.name;
