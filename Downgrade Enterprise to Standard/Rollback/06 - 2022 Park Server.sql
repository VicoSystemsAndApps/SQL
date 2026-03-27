-- Keep 2022 databases inaccessible
DECLARE @sql nvarchar(max) = N'';
SELECT	@sql = @sql + N'ALTER DATABASE ' + QUOTENAME(name) + N' SET READ_ONLY;'
FROM	sys.databases 
WHERE	database_id > 4 
AND		state_desc	= 'ONLINE';

EXEC sp_executesql @sql;

-- Or take them offline if preferred:
-- ALTER DATABASE [YourDB] SET OFFLINE WITH ROLLBACK IMMEDIATE;
