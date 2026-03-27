/*
Red flags: Orphans after restores/migrations (can cause broken access or mis-mapped users).

- Orphaned users can’t connect → “Login failed. The login is from an untrusted domain and cannot be used with Windows authentication.”
- Creates mystery accounts inside the DB (confuses audits, RBAC clarity).
- May signal incomplete migrations
*/

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#OrphanedUsers') IS NOT NULL DROP TABLE #OrphanedUsers;
CREATE TABLE #OrphanedUsers
(
    DatabaseName SYSNAME
,   UserName     SYSNAME
,   UserType     NVARCHAR(60)
,   sid          VARBINARY(85)
);

DECLARE @db  SYSNAME
,       @sql NVARCHAR(MAX);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT name
    FROM    sys.databases
    WHERE   database_id > 4   -- user DBs
    AND     state       = 0;  -- online

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
        USE ' + QUOTENAME(@db) + N';
        SELECT      DB_NAME()           AS DatabaseName
        ,           dp.name             AS UserName
        ,           dp.type_desc        AS UserType
        ,           dp.sid
        FROM        sys.database_principals dp
        LEFT JOIN   sys.server_principals   sp ON sp.sid = dp.sid
        WHERE       dp.type IN (''S'',''U'')   -- SQL user, Windows user
        AND         dp.sid  IS NOT NULL
        AND         sp.sid  IS NULL;';

    INSERT INTO #OrphanedUsers 
                (DatabaseName, UserName, UserType, sid)
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs; DEALLOCATE dbs;

-- Final report
SELECT      *
FROM        #OrphanedUsers
ORDER BY    DatabaseName
,           UserName;
