DECLARE @ag     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE ags CURSOR FOR

SELECT      ag.name
FROM        sys.availability_groups             ag
LEFT JOIN   sys.availability_databases_cluster  adc  ON ag.group_id = adc.group_id
WHERE       adc.database_name IS NULL;

OPEN ags;
FETCH NEXT FROM ags INTO @ag;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = 'DROP AVAILABILITY GROUP ' + QUOTENAME(@ag) + ';';

    PRINT @sql;    -- review first
    -- EXEC(@sql); -- uncomment to execute

    FETCH NEXT FROM ags INTO @ag;
END

CLOSE ags;
DEALLOCATE ags;
