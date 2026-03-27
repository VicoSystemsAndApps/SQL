-- Red flags: Unexpected logins/users in db_owner, db_securityadmin.

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#DbRoleMembers') IS NOT NULL DROP TABLE #DbRoleMembers;
CREATE TABLE #DbRoleMembers
(
    DatabaseName SYSNAME
,   DbRole       SYSNAME
,   MemberName   SYSNAME
,   MemberType   NVARCHAR(60)
);

DECLARE @db  SYSNAME
,       @sql NVARCHAR(MAX);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT  name
    FROM    sys.databases
    WHERE   database_id > 4        -- user DBs
    AND     state = 0;             -- online

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
        USE ' + QUOTENAME(@db) + N';
        SELECT  DB_NAME()                 AS DatabaseName
        ,       r.name                    AS DbRole
        ,       m.name                    AS MemberName
        ,       m.type_desc               AS MemberType
        FROM    sys.database_role_members drm
        JOIN    sys.database_principals   r ON r.principal_id = drm.role_principal_id
        JOIN    sys.database_principals   m ON m.principal_id = drm.member_principal_id
        WHERE   r.name IN (''db_owner'',''db_securityadmin'');';

    INSERT INTO #DbRoleMembers 
                (DatabaseName, DbRole, MemberName, MemberType)
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs; DEALLOCATE dbs;

SELECT      *
FROM        #DbRoleMembers
ORDER BY    DatabaseName
,           DbRole
,           MemberName;
