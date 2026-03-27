-- On 2016: enable app logins and jobs
ALTER LOGIN [AppLogin1] ENABLE;
ALTER LOGIN [AppLogin2] ENABLE;

DECLARE c CURSOR FAST_FORWARD FOR
    SELECT job_id FROM msdb.dbo.sysjobs;
    DECLARE @job uniqueidentifier;
    OPEN c;
    FETCH NEXT FROM c INTO @job;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC msdb.dbo.sp_update_job @job_id = @job, @enabled = 1;
        FETCH NEXT FROM c INTO @job;
    END
CLOSE c; DEALLOCATE c;

-- Ensure DBs are online & MULTI_USER
DECLARE @sql nvarchar(max) = N'';

SELECT  @sql = @sql + N'ALTER DATABASE ' + QUOTENAME(name) + N' SET MULTI_USER;'
FROM    sys.databases 
WHERE   database_id > 4;

EXEC sp_executesql @sql;
