-- Lists all operators being used in procedures etc

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR FOR
SELECT  name
FROM    sys.databases
WHERE   state_desc  = 'ONLINE'
AND     database_id > 4; -- Skip system DBs (master, model, msdb, tempdb)

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    IF DB_ID(''' + @db + ''') IS NOT NULL
    BEGIN
        USE ' + QUOTENAME(@db) + ';

        SELECT  DB_NAME()                       AS database_name
        ,       OBJECT_SCHEMA_NAME(o.object_id) AS schema_name
        ,       OBJECT_NAME(o.object_id)        AS object_name
        ,       o.type_desc                     AS object_type
        FROM    sys.objects     o
        JOIN    sys.sql_modules m ON m.object_id = o.object_id
        WHERE   m.definition LIKE ''%sp_notify_operator%''
        OR      m.definition LIKE ''%sp_send_dbmail%'';
    END;
    ';

    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;