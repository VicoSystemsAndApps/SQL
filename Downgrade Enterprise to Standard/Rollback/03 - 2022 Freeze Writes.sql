-- On 2022: block new connections & terminate active user sessions
-- Option A: at database level
DECLARE @sql nvarchar(max) = N'';

SELECT  @sql = @sql + N'ALTER DATABASE ' + QUOTENAME(name) +
              N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;'
FROM    sys.databases 
WHERE   database_id > 4 
AND     state_desc  = 'ONLINE';

EXEC sp_executesql @sql;

-- Option B (coarser): DISABLE app logins
-- ALTER LOGIN [AppLogin1] DISABLE;  -- repeat for each app login
