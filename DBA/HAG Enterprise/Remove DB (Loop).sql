DECLARE @db     SYSNAME
,       @ag     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE dbs CURSOR FOR

SELECT  d.name
FROM    sys.databases d
WHERE   d.database_id   > 4
AND     d.state         = 0                 -- ONLINE
AND     d.name          NOT IN  (   'DBAMaint'
                                ,   'SQLMAINT'
                                ) -- exclusions
AND     d.name          IN  (
                            SELECT  database_name 
                            FROM    sys.availability_databases_cluster
                            );

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Find AG for this database
    SELECT  @ag = ag.name
    FROM    sys.availability_groups             ag
    JOIN    sys.availability_databases_cluster  adc  ON ag.group_id = adc.group_id
    WHERE   adc.database_name = @db;

    -- Build ALTER statements
    SET @sql = '
                -- Database: ' + QUOTENAME(@db) + '
                ALTER AVAILABILITY GROUP ' + QUOTENAME(@ag) + ' REMOVE DATABASE ' + QUOTENAME(@db) + ';
                --ALTER DATABASE ' + QUOTENAME(@db) + ' SET OFFLINE WITH ROLLBACK IMMEDIATE;
                ';

    PRINT @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;
