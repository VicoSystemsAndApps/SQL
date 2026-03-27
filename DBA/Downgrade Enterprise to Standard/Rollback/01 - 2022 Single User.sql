-- On 2022: ensure user DBs aren’t left accessible
DECLARE @sql nvarchar(max) = N'';
SELECT	@sql = @sql + N'ALTER DATABASE ' + QUOTENAME(name) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;'
FROM	sys.databases 
WHERE	database_id > 4 
AND		state_desc	= 'ONLINE';

EXEC sp_executesql @sql;
