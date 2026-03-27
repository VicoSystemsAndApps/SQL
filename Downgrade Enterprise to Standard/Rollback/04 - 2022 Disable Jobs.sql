DECLARE c CURSOR FAST_FORWARD FOR
    SELECT job_id FROM msdb.dbo.sysjobs;
    
    DECLARE @job uniqueidentifier;
    OPEN c;
    FETCH NEXT FROM c INTO @job;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC msdb.dbo.sp_update_job @job_id = @job, @enabled = 0;
        FETCH NEXT FROM c INTO @job;
    END
CLOSE c; DEALLOCATE c;
