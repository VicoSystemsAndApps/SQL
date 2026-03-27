SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#Agg') IS NOT NULL DROP TABLE #Agg;
CREATE TABLE #Agg
(
    DatabaseName        SYSNAME       NOT NULL
,   DbUser              SYSNAME       NOT NULL
,   LoginName           SYSNAME       NULL
,   LoginType           NVARCHAR(60)  NULL
,   AuthType            NVARCHAR(60)  NULL
,   IsOrphaned          CHAR(3)       NULL
,   DifferentSID        CHAR(3)       NULL
,   LoginDisabled       CHAR(3)       NULL
,   Roles               NVARCHAR(MAX) NULL
,   DatabasePermissions NVARCHAR(MAX) NULL
,   SchemaPermissions   NVARCHAR(MAX) NULL
,   ServerRoles         NVARCHAR(MAX) NULL
,   ServerPermissions   NVARCHAR(MAX) NULL
);

DECLARE @db     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR

SELECT  name
FROM    sys.databases
WHERE   state_desc  = 'ONLINE'
AND     database_id > 4;  -- user DBs only

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
                USE ' + QUOTENAME(@db) + N';

                IF OBJECT_ID(''tempdb..#Principals'') IS NOT NULL DROP TABLE #Principals;
                
                CREATE TABLE #Principals
                (
                    principal_id    INT
                ,   DbUser          SYSNAME
                ,   LoginName       SYSNAME        NULL
                ,   LoginType       NVARCHAR(60)   NULL
                ,   AuthType        NVARCHAR(60)   NULL
                ,   IsOrphaned      NCHAR(3)
                ,   DifferentSID    NCHAR(3)
                ,   LoginDisabled   NCHAR(3)
                );

                INSERT INTO #Principals 
                            (principal_id, DbUser, LoginName, LoginType, AuthType, IsOrphaned, DifferentSID, LoginDisabled)
                SELECT      dp.principal_id
                ,           dp.name                                         AS DbUser
                ,           sp_name.name                                    AS LoginByName
                ,           dp.type_desc                                    AS DbUserType
                ,           dp.authentication_type_desc                     AS AuthType
                ,           IIF(sp_sid.name IS NULL, ''Yes'', ''No'')       AS IsOrphaned
                ,           IIF(    sp_name.sid IS NOT NULL
                                AND dp.sid IS NOT NULL
                                AND sp_name.sid != dp.sid
                                , ''Yes'', ''No''
                            )                                               AS DifferentSID
                ,           IIF(sp_sid.is_disabled = 1, ''Yes'', ''No'')    AS LoginDisabled
                FROM        sys.database_principals dp
                LEFT JOIN   sys.server_principals   sp_sid  ON dp.sid       = sp_sid.sid                  
                LEFT JOIN   sys.server_principals   sp_name ON sp_name.name COLLATE DATABASE_DEFAULT = dp.name COLLATE DATABASE_DEFAULT
                WHERE       dp.type IN (''S'',''U'',''G'',''E'',''X'')
                AND         dp.name NOT IN  (   ''dbo''
                                            ,   ''sys''
                                            ,   ''guest''
                                            ,   ''INFORMATION_SCHEMA''
                                            ,   ''NT AUTHORITY\NETWORK SERVICE''
                                            )
                AND         dp.name NOT LIKE ''##%'';



                INSERT INTO     #Agg 
                                (   DatabaseName, DbUser, LoginName, LoginType, AuthType, IsOrphaned, DifferentSID, LoginDisabled
                                ,   Roles, DatabasePermissions, SchemaPermissions, ServerRoles, ServerPermissions
                                )
                SELECT          DB_NAME() AS DatabaseName
                ,               p.DbUser
                ,               p.LoginName
                ,               p.LoginType
                ,               p.AuthType
                ,               p.IsOrphaned
                ,               p.DifferentSID
                ,               p.LoginDisabled

                -- Roles list
                ,               Roles = STUFF((
                                                SELECT      N'','' + CONVERT(nvarchar(256), r.name) COLLATE DATABASE_DEFAULT
                                                FROM        sys.database_role_members   drm
                                                JOIN        sys.database_principals     r ON r.principal_id = drm.role_principal_id
                                                WHERE       drm.member_principal_id = p.principal_id
                                                ORDER BY    r.name
                                                FOR         XML PATH(''''), TYPE
                                                ).value(''.'', ''nvarchar(max)''), 1, 1, N'''')

                -- Database-level permissions list (class=0)
                ,               DatabasePerms = STUFF((
                                                        SELECT      N'',''
                                                                    + (CONVERT(nvarchar(256), dpperm.permission_name) COLLATE DATABASE_DEFAULT)
                                                                    + N'':'' +
                                                                    (CONVERT(nvarchar(256), dpperm.state_desc) COLLATE DATABASE_DEFAULT)
                                                        FROM        sys.database_permissions dpperm
                                                        WHERE       dpperm.grantee_principal_id = p.principal_id
                                                        AND         dpperm.class = 0
                                                        ORDER BY    dpperm.permission_name
                                                        ,           dpperm.state_desc
                                                        FOR         XML PATH(''''), TYPE
                                                        ).value(''.'', ''nvarchar(max)''), 1, 1, N'''')

                -- Schema-level permissions list (class=3)
                ,               SchemaPerms = STUFF((
                                                        SELECT      N'',''
                                                                    + (CONVERT(nvarchar(256), s.name) COLLATE DATABASE_DEFAULT)
                                                                    + N''|''
                                                                    + (CONVERT(nvarchar(256), dpperm.permission_name) COLLATE DATABASE_DEFAULT)
                                                                    + N'':'' +
                                                                    (CONVERT(nvarchar(256), dpperm.state_desc) COLLATE DATABASE_DEFAULT)
                                                        FROM        sys.database_permissions    dpperm
                                                        JOIN        sys.schemas                 s       ON  dpperm.class    = 3 
                                                                                                        AND dpperm.major_id = s.schema_id
                                                        WHERE       dpperm.grantee_principal_id = p.principal_id
                                                        ORDER BY    s.name
                                                        ,           dpperm.permission_name
                                                        ,           dpperm.state_desc
                                                        FOR         XML PATH(''''), TYPE
                                                        ).value(''.'', ''nvarchar(max)''), 1, 1, N'''')
               
                ,               ServerRoles = STUFF((
                                                        SELECT      N'','' + 
                                                                    CONVERT(nvarchar(256), r.name) COLLATE DATABASE_DEFAULT
                                                        FROM        sys.server_role_members rm
                                                        JOIN        sys.server_principals   r ON r.principal_id = rm.role_principal_id
                                                        WHERE       rm.member_principal_id = p.principal_id
                                                        ORDER BY    r.name
                                                        FOR         XML PATH(''''), TYPE
                                                        ).value(''.'', ''nvarchar(max)''), 1, 1, N'''')
               
               ,                ServerPerms = STUFF((
                                                        SELECT      N'','' 
                                                                    + (CONVERT(nvarchar(256), sp.permission_name) COLLATE DATABASE_DEFAULT)
                                                                    + N'':'' 
                                                                    + (CONVERT(nvarchar(256), sp.state_desc) COLLATE DATABASE_DEFAULT)
                                                        FROM        sys.server_permissions sp
                                                        WHERE       sp.grantee_principal_id = p.principal_id
                                                        ORDER BY    sp.permission_name
                                                        ,           sp.state_desc
                                                        FOR         XML PATH(''''), TYPE
                                                        ).value(''.'', ''nvarchar(max)''), 1, 1, N'''')

                FROM            #Principals p;
                ';

    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM db_cursor INTO @db;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT      @@SERVERNAME AS ServerName
,           *
FROM        #Agg
ORDER BY    DatabaseName
,           DbUser;

