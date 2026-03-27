
USE Master;
GO

-- CONFIGURE ----------------------------------------------------------------------
DECLARE @User sysname       = N'user';         -- desired username
DECLARE @Pwd  nvarchar(128) = N'';   -- strong, unique


-- CREATE USER IN MASTER ----------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @User)
BEGIN
    DECLARE @sql nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(@User) + 
        N' WITH PASSWORD = N''' + REPLACE(@Pwd, '''', '''''') + N''';';
    EXEC (@sql);
END
ELSE
BEGIN
    PRINT 'User already exists in master.';
END
GO

-- Allow DBA to create/drop DBs and manage users ------------------------------------
ALTER ROLE dbmanager    ADD MEMBER [user];


-- CONFIGURE ----------------------------------------------------------------------
DECLARE @User sysname       = N'user';         -- desired username
DECLARE @Pwd  nvarchar(128) = N'';   -- strong, unique


-- Run and then run output to create DB by DB user -----------------------------------
SELECT      CONCAT  (
                    '/* ===== ', QUOTENAME(name), ' ===== */
                    USE ', QUOTENAME(name), ';
                    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''', @User, ''')
                        CREATE USER ', QUOTENAME(@User), ' WITH PASSWORD = N''', @Pwd, ''';

                    -- Elevate within this database
                    ALTER ROLE db_owner ADD MEMBER ', QUOTENAME(@User), ';

                    -- Helpful for perf troubleshooting and masked data (optional)
                    GRANT VIEW DATABASE STATE TO ', QUOTENAME(@User), ';
                    GRANT UNMASK TO ', QUOTENAME(@User), ';
                    ')
FROM        sys.databases
WHERE       name != 'master'
ORDER BY    name;

                      



                     

