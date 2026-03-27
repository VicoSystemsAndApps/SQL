/*
    Red flags: Many contained users you didn’t expect; UNSAFE/EXTERNAL_ACCESS assemblies.

    - Contained users (authentication_type_desc = DATABASE or NONE) mean credentials are stored inside the database 
    (not mapped to server logins). This is expected for contained DB scenarios, but be cautious:

        - Confirm which applications require contained users.
        - Check password policies & lifecycle for those accounts.
        - Make sure contained DBs have appropriate access controls and monitoring.

    - Assemblies with EXTERNAL_ACCESS or UNSAFE can execute code outside SQL Server or run unmanaged code:

        - UNSAFE is the highest risk — treat any unexpected UNSAFE assembly as a red flag
        - EXTERNAL_ACCESS allows file/OS/network interactions and should be audited and justified.
        - Verify the owner of the DB (not sa), review the assembly origin/signature, and consider 
        requiring AUTHORIZATION or certificate signing.

*/

SET NOCOUNT ON;

-- Cleanup old temp tables if present
IF OBJECT_ID('tempdb..#ContainedUsers') IS NOT NULL DROP TABLE #ContainedUsers;
IF OBJECT_ID('tempdb..#RiskyAssemblies') IS NOT NULL DROP TABLE #RiskyAssemblies;

-- Create temp tables to collect results
CREATE TABLE #ContainedUsers
(
    DatabaseName            SYSNAME
,   PrincipalName           SYSNAME
,   PrincipalType           NVARCHAR(60)
,   AuthenticationTypeDesc  NVARCHAR(60),
    PrincipalId             INT
);

CREATE TABLE #RiskyAssemblies
(
    DatabaseName        SYSNAME
,   AssemblyName        SYSNAME
,   PermissionSetDesc   NVARCHAR(60)
);

DECLARE @db     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
SELECT  name
FROM    sys.databases
WHERE   database_id > 4   -- user DBs only
AND     state       = 0;  -- online

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Contained users (authentication_type_desc = DATABASE or NONE)
    SET @sql = N'
        USE ' + QUOTENAME(@db) + N';
        SELECT  DB_NAME()                   AS DatabaseName
        ,       name                        AS PrincipalName
        ,       type_desc                   AS PrincipalType
        ,       authentication_type_desc    AS AuthenticationTypeDesc
        ,       principal_id                AS PrincipalId
        FROM    sys.database_principals
        WHERE   authentication_type_desc IN (''DATABASE'',''NONE'')  -- contained, cert/asym key
        AND     principal_id > 4;';

    INSERT INTO #ContainedUsers 
                (DatabaseName, PrincipalName, PrincipalType, AuthenticationTypeDesc, PrincipalId)
    EXEC sys.sp_executesql @sql;

    -- Assemblies with EXTERNAL_ACCESS or UNSAFE
    SET @sql = N'
        USE ' + QUOTENAME(@db) + N';
        SELECT  DB_NAME()           AS DatabaseName
        ,       name                AS AssemblyName
        ,       permission_set_desc AS PermissionSetDesc
        FROM    sys.assemblies
        WHERE   permission_set_desc IN (''EXTERNAL_ACCESS'',''UNSAFE'');';

    INSERT INTO #RiskyAssemblies 
                (DatabaseName, AssemblyName, PermissionSetDesc)
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;

-- Final output: contained users
SELECT      *
FROM        #ContainedUsers
ORDER BY    DatabaseName
,           PrincipalName;

-- Final output: risky assemblies
SELECT      *
FROM        #RiskyAssemblies
ORDER BY    DatabaseName
,           AssemblyName;

-- Cleanup if you want (optional)
-- DROP TABLE #ContainedUsers;
-- DROP TABLE #RiskyAssemblies;
