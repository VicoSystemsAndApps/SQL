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
,   Roles               NVARCHAR(MAX) NULL
,   DatabasePermissions NVARCHAR(MAX) NULL
,   SchemaPermissions   NVARCHAR(MAX) NULL
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
                    DatabaseName    SYSNAME
                ,   principal_id    INT
                ,   DbUser          SYSNAME
                ,   LoginName       SYSNAME        NULL
                ,   LoginType       NVARCHAR(60)   NULL
                ,   AuthType        NVARCHAR(60)   NULL
                ,   IsOrphaned      CHAR(3)
                ,   DifferentSID    CHAR(3)
                );

                INSERT INTO #Principals 
                            (DatabaseName, principal_id, DbUser, LoginName, LoginType, AuthType, IsOrphaned, DifferentSID)
                SELECT      DB_NAME()
                ,           dp.principal_id
                ,           dp.name                                     AS DbUser
                ,           sp_name.name                                AS LoginByName
                ,           dp.type_desc                                AS DbUserType
                ,           dp.authentication_type_desc                 AS AuthType
                ,           IIF(sp_sid.name IS NULL, ''Yes'', ''No'')   AS IsOrphaned
                ,           IIF(    sp_name.sid IS NOT NULL
                                AND dp.sid IS NOT NULL
                                AND sp_name.sid != dp.sid
                                , ''Yes'', ''No''
                            )                                           AS DifferentSID
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


                WITH RoleAgg AS
                (
                SELECT      drm.member_principal_id                                                     AS principal_id
                ,           STRING_AGG(CONVERT(nvarchar(256), r.name) COLLATE DATABASE_DEFAULT, N'','') AS Roles
                FROM        sys.database_role_members   drm
                JOIN        sys.database_principals     r   ON r.principal_id = drm.role_principal_id
                GROUP BY    drm.member_principal_id
                )
                , DbPermAgg AS
                (
                SELECT      dpperm.grantee_principal_id                                                         AS principal_id
                ,           STRING_AGG(
                                    (CONVERT(nvarchar(256), dpperm.permission_name) COLLATE DATABASE_DEFAULT) + 
                                    N'':'' +
                                    (CONVERT(nvarchar(256), dpperm.state_desc) COLLATE DATABASE_DEFAULT)
                                    , N'',''
                            )                                                                                   AS DatabasePermissions
                FROM        sys.database_permissions dpperm
                WHERE       dpperm.class = 0
                GROUP BY    dpperm.grantee_principal_id
                )
                , SchemaPermAgg AS
                (
                SELECT      dpperm.grantee_principal_id                                                         AS principal_id
                ,           STRING_AGG(
                                    (CONVERT(nvarchar(256), s.name) COLLATE DATABASE_DEFAULT) + 
                                    N''|'' +
                                    (CONVERT(nvarchar(256), dpperm.permission_name) COLLATE DATABASE_DEFAULT) + 
                                    N'':'' +
                                    (CONVERT(nvarchar(256), dpperm.state_desc) COLLATE DATABASE_DEFAULT)
                                    , N'',''
                            )                                                                                   AS SchemaPermissions
                FROM        sys.database_permissions    dpperm
                JOIN        sys.schemas                 s       ON  dpperm.class        = 3 
                                                                AND dpperm.major_id     = s.schema_id
                GROUP BY    dpperm.grantee_principal_id
                )
                INSERT INTO #Agg 
                            (DatabaseName, DbUser, LoginName, LoginType, AuthType, IsOrphaned, DifferentSID, Roles, DatabasePermissions, SchemaPermissions)
                SELECT      p.DatabaseName
                ,           p.DbUser
                ,           p.LoginName
                ,           p.LoginType
                ,           p.AuthType
                ,           p.IsOrphaned
                ,           p.DifferentSID
                ,           ra.Roles
                ,           dba.DatabasePermissions
                ,           spa.SchemaPermissions
                FROM        #Principals     p
                LEFT JOIN   RoleAgg         ra  ON ra.principal_id  = p.principal_id
                LEFT JOIN   DbPermAgg       dba ON dba.principal_id = p.principal_id
                LEFT JOIN   SchemaPermAgg   spa ON spa.principal_id = p.principal_id;
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
