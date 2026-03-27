/*  Script SQL Agent jobs (steps + schedules + notifications) 
    Set @JobName to a specific job, or NULL to script all jobs 

    NB - Any jobs with a guid, remove @job_id parameter
*/

USE msdb;
GO
SET NOCOUNT ON;

DECLARE @JobName sysname = NULL;  -- e.g. N'My Job'; NULL = all jobs

DECLARE @cr CURSOR;
IF @JobName IS NULL
    SET @cr = CURSOR FAST_FORWARD FOR
      SELECT job_id FROM msdb.dbo.sysjobs ORDER BY name;
ELSE
    SET @cr = CURSOR FAST_FORWARD FOR
      SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @JobName;

OPEN @cr;

DECLARE @job_id UNIQUEIDENTIFIER;

FETCH NEXT FROM @cr INTO @job_id;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE
        @name sysname,
        @enabled INT,
        @description NVARCHAR(512),
        @owner_sid VARBINARY(85),
        @owner_login_name sysname;

    SELECT
        @name = j.name,
        @enabled = j.enabled,
        @description = j.description,
        @owner_sid = j.owner_sid
    FROM msdb.dbo.sysjobs AS j
    WHERE j.job_id = @job_id;

    SELECT @owner_login_name = SUSER_SNAME(@owner_sid);

    PRINT '/* ===== BEGIN SCRIPT FOR JOB: ' + REPLACE(@name,'''','''''') + ' ===== */';

    -- Create job shell
    PRINT 'EXEC msdb.dbo.sp_add_job @job_name = N''' + REPLACE(@name,'''','''''') + ''',';
    PRINT '    @enabled = ' + CAST(@enabled AS VARCHAR(10)) + ',';
    PRINT '    @description = N''' + REPLACE(ISNULL(@description,N''),'''','''''') + ''',';
    PRINT '    @owner_login_name = N''' + REPLACE(ISNULL(@owner_login_name,N'sa'),'''','''''') + ''';';
    PRINT 'GO';

    /* Steps */
    DECLARE
        @step_id INT,
        @step_name sysname,
        @subsystem NVARCHAR(40),
        @command NVARCHAR(MAX),
        @database_name sysname,
        @on_success_action INT,
        @on_fail_action INT,
        @retry_attempts INT,
        @retry_interval INT;

    DECLARE step_cur CURSOR FAST_FORWARD FOR
        SELECT step_id, step_name, subsystem, command, database_name,
               on_success_action, on_fail_action, retry_attempts, retry_interval
        FROM msdb.dbo.sysjobsteps
        WHERE job_id = @job_id
        ORDER BY step_id;

    OPEN step_cur;
    FETCH NEXT FROM step_cur INTO
        @step_id, @step_name, @subsystem, @command, @database_name,
        @on_success_action, @on_fail_action, @retry_attempts, @retry_interval;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'EXEC msdb.dbo.sp_add_jobstep @job_name = N''' + REPLACE(@name,'''','''''') + ''','
            + ' @step_id = ' + CAST(@step_id AS VARCHAR(10))
            + ', @step_name = N''' + REPLACE(@step_name,'''','''''') + ''''
            + ', @subsystem = N''' + @subsystem + ''''
            + CASE WHEN @database_name IS NOT NULL
                   THEN ', @database_name = N''' + REPLACE(@database_name,'''','''''') + ''''
                   ELSE '' END
            + ', @command = N''' + REPLACE(@command,'''','''''') + ''''
            + ', @on_success_action = ' + CAST(@on_success_action AS VARCHAR(10))
            + ', @on_fail_action = ' + CAST(@on_fail_action AS VARCHAR(10))
            + ', @retry_attempts = ' + CAST(@retry_attempts AS VARCHAR(10))
            + ', @retry_interval = ' + CAST(@retry_interval AS VARCHAR(10)) + ';';
        PRINT 'GO';

        FETCH NEXT FROM step_cur INTO
            @step_id, @step_name, @subsystem, @command, @database_name,
            @on_success_action, @on_fail_action, @retry_attempts, @retry_interval;
    END
    CLOSE step_cur; DEALLOCATE step_cur;

    /* Schedules */
    DECLARE
        @sched_name sysname, @sched_enabled INT, @freq_type INT, @freq_interval INT,
        @freq_subday_type INT, @freq_subday_interval INT, @freq_relative_interval INT,
        @freq_recurrence_factor INT, @active_start_date INT, @active_start_time INT,
        @active_end_date INT, @active_end_time INT;

    DECLARE sch_cur CURSOR FAST_FORWARD FOR
        SELECT s.name, s.enabled, s.freq_type, s.freq_interval, s.freq_subday_type,
               s.freq_subday_interval, s.freq_relative_interval, s.freq_recurrence_factor,
               s.active_start_date, s.active_start_time, s.active_end_date, s.active_end_time
        FROM msdb.dbo.sysjobschedules js
        JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
        WHERE js.job_id = @job_id;

    OPEN sch_cur;
    FETCH NEXT FROM sch_cur INTO
        @sched_name, @sched_enabled, @freq_type, @freq_interval, @freq_subday_type,
        @freq_subday_interval, @freq_relative_interval, @freq_recurrence_factor,
        @active_start_date, @active_start_time, @active_end_date, @active_end_time;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'EXEC msdb.dbo.sp_add_jobschedule @job_name = N''' + REPLACE(@name,'''','''''') + ''','
            + ' @name = N''' + REPLACE(@sched_name,'''','''''') + ''''
            + ', @enabled = ' + CAST(@sched_enabled AS VARCHAR(10))
            + ', @freq_type = ' + CAST(@freq_type AS VARCHAR(10))
            + ', @freq_interval = ' + CAST(@freq_interval AS VARCHAR(10))
            + ', @freq_subday_type = ' + CAST(@freq_subday_type AS VARCHAR(10))
            + ', @freq_subday_interval = ' + CAST(@freq_subday_interval AS VARCHAR(10))
            + ', @freq_relative_interval = ' + CAST(ISNULL(@freq_relative_interval,0) AS VARCHAR(10))
            + ', @freq_recurrence_factor = ' + CAST(ISNULL(@freq_recurrence_factor,0) AS VARCHAR(10))
            + ', @active_start_date = ' + CAST(@active_start_date AS VARCHAR(10))
            + ', @active_start_time = ' + CAST(@active_start_time AS VARCHAR(10))
            + ', @active_end_date = ' + CAST(@active_end_date AS VARCHAR(10))
            + ', @active_end_time = ' + CAST(@active_end_time AS VARCHAR(10)) + ';';
        PRINT 'GO';

        FETCH NEXT FROM sch_cur INTO
            @sched_name, @sched_enabled, @freq_type, @freq_interval, @freq_subday_type,
            @freq_subday_interval, @freq_relative_interval, @freq_recurrence_factor,
            @active_start_date, @active_start_time, @active_end_date, @active_end_time;
    END
    CLOSE sch_cur; DEALLOCATE sch_cur;

    /* Notifications */
    DECLARE
        @notify_level_eventlog INT,
        @notify_level_email INT,
        @notify_level_netsend INT,
        @notify_level_page INT,
        @notify_email_operator_id INT,
        @email_operator_name sysname;

    SELECT
        @notify_level_eventlog = notify_level_eventlog,
        @notify_level_email     = notify_level_email,
        @notify_level_netsend   = notify_level_netsend,
        @notify_level_page      = notify_level_page,
        @notify_email_operator_id = notify_email_operator_id
    FROM msdb.dbo.sysjobs
    WHERE job_id = @job_id;

    SELECT @email_operator_name = o.name
    FROM msdb.dbo.sysoperators o
    WHERE o.id = @notify_email_operator_id;

    IF COALESCE(@notify_level_eventlog, @notify_level_email, @notify_level_netsend, @notify_level_page) IS NOT NULL
    BEGIN
        PRINT 'EXEC msdb.dbo.sp_update_job @job_name = N''' + REPLACE(@name,'''','''''') + ''','
            + ' @notify_level_eventlog = ' + COALESCE(CAST(@notify_level_eventlog AS VARCHAR(10)),'0')
            + ', @notify_level_email = ' + COALESCE(CAST(@notify_level_email AS VARCHAR(10)),'0')
            + ', @notify_level_netsend = ' + COALESCE(CAST(@notify_level_netsend AS VARCHAR(10)),'0')
            + ', @notify_level_page = ' + COALESCE(CAST(@notify_level_page AS VARCHAR(10)),'0') + ';';
        PRINT 'GO';

        IF @email_operator_name IS NOT NULL
        BEGIN
            PRINT 'EXEC msdb.dbo.sp_update_job @job_name = N''' + REPLACE(@name,'''','''''') + ''','
                + ' @email_operator_name = N''' + REPLACE(@email_operator_name,'''','''''') + ''';';
            PRINT 'GO';
        END
    END

    /* Attach to local server */
    PRINT 'EXEC msdb.dbo.sp_add_jobserver @job_name = N''' + REPLACE(@name,'''','''''') + ''', @server_name = N''(LOCAL)'';';
    PRINT 'GO';
    PRINT '/* ===== END SCRIPT FOR JOB: ' + REPLACE(@name,'''','''''') + ' ===== */';
    PRINT '';

    FETCH NEXT FROM @cr INTO @job_id;
END

CLOSE @cr; DEALLOCATE @cr;
GO
