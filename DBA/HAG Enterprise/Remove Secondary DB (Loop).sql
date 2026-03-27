DECLARE @db     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE dbs CURSOR FOR

SELECT  name
FROM    sys.databases
WHERE   state_desc = 'RESTORING';

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql =  '
                RESTORE DATABASE ' + QUOTENAME(@db) + ' WITH RECOVERY;
                DROP DATABASE ' + QUOTENAME(@db) + ';
                ';

    PRINT @sql;     -- change to EXEC(@sql) when ready
    -- EXEC(@sql);  -- uncomment to actually run

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;
