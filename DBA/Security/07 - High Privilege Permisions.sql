-- Red flags: CONTROL on DB or key objects, IMPERSONATE grants, liberal VIEW DEFINITION where not needed.

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#DbPermissions') IS NOT NULL DROP TABLE #DbPermissions;
CREATE TABLE #DbPermissions
(
    DatabaseName    SYSNAME
,   Principal       SYSNAME
,   PrincipalType   NVARCHAR(60)
,   StateDesc       NVARCHAR(60)
,   PermissionName  NVARCHAR(100)
,   [Schema]        SYSNAME NULL
,   [Object]        SYSNAME NULL
);

DECLARE @db  SYSNAME
,       @sql NVARCHAR(MAX);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT  name
    FROM    sys.databases
    WHERE   database_id > 4   -- user DBs only
    AND     state       = 0;  -- online

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N';
        SELECT  DB_NAME()                       AS DatabaseName
        ,       u.name                          AS Principal
        ,       u.type_desc                     AS PrincipalType
        ,       dp.state_desc
        ,       dp.permission_name
        ,       OBJECT_SCHEMA_NAME(dp.major_id) AS [Schema]
        ,       OBJECT_NAME(dp.major_id)        AS [Object]
        FROM    sys.database_permissions   dp
        JOIN    sys.database_principals    u  ON u.principal_id = dp.grantee_principal_id
        WHERE   dp.state_desc LIKE ''GRANT%''
        AND     dp.permission_name IN (
                                        ''CONTROL'',''IMPERSONATE'',''ALTER ANY USER'',
                                        ''ALTER ANY SCHEMA'',''ALTER ANY ROLE'',
                                        ''ALTER ANY APPLICATION ROLE'',''VIEW DEFINITION''
                                        )
       ORDER BY u.name
       ,        dp.permission_name;';

    INSERT INTO #DbPermissions
                (DatabaseName, Principal, PrincipalType, StateDesc, PermissionName, [Schema], [Object])
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs; DEALLOCATE dbs;

-- Final report
SELECT      *
FROM        #DbPermissions
ORDER BY    DatabaseName
,           Principal
,           PermissionName;
