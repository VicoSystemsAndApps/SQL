/* ===========================
   DBA Core & HADR Alerts
   Creates/links alerts to Operator 'DBA'
   Safe to re-run.
   =========================== 
*/

USE [msdb];
GO

/* --------- CONFIG --------- */
DECLARE     @OperatorName  sysname        = N'DBA'
,           @OperatorEmail NVARCHAR(256)  = N'WDH-SystemsAndApplic@vicohomes.co.uk' -- <- CHANGE ME
,           @DelaySeconds  INT            = 300;  -- throttle per-alert notifications
/* -------------------------- */

/* 1) Ensure Operator exists */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
BEGIN
    EXEC msdb.dbo.sp_add_operator
        @name                        = @OperatorName
    ,   @enabled                     = 1
    ,   @email_address               = @OperatorEmail
    ,   @weekday_pager_start_time    = 000000  -- 24x7 by default
    ,   @weekday_pager_end_time      = 235959
    ,   @saturday_pager_start_time   = 000000
    ,   @saturday_pager_end_time     = 235959
    ,   @sunday_pager_start_time     = 000000
    ,   @sunday_pager_end_time       = 235959;
END
ELSE
BEGIN
    -- keep operator up to date with current email
    EXEC msdb.dbo.sp_update_operator
        @name           = @OperatorName
    ,   @email_address  = @OperatorEmail
    ,   @enabled        = 1;
END
GO

/* 2) Helper: create-or-update alert + link to operator */
IF OBJECT_ID('tempdb..#AlertsToCreate') IS NOT NULL DROP TABLE #AlertsToCreate;
CREATE TABLE #AlertsToCreate
(
    AlertName                 NVARCHAR(256) NOT NULL
,   Severity                  INT           NULL      -- for severity-based
,   MessageID                 INT           NULL      -- for specific error number
,   PerformanceCondition      NVARCHAR(512) NULL      -- for perf alerts
,   IncludeEventDescription   TINYINT       NOT NULL DEFAULT(1)
);

/* ---- Core Severity Alerts (17–25) ---- */
INSERT INTO #AlertsToCreate (AlertName, Severity)
VALUES      (N'DBA - Severity 17 (Insufficient Resources)', 17)
,           (N'DBA - Severity 18 (Nonfatal Internal Error)', 18)
,           (N'DBA - Severity 19 (Resource Limit Exceeded)', 19)
,           (N'DBA - Severity 20 (Fatal Error In Current Process)', 20)
,           (N'DBA - Severity 21 (Fatal Error In Database Process)', 21)
,           (N'DBA - Severity 22 (Table/DB Integrity Suspect)', 22)
,           (N'DBA - Severity 23 (Database Integrity Suspect)', 23)
,           (N'DBA - Severity 24 (Hardware/Media Failure)', 24)
,           (N'DBA - Severity 25 (System Error)', 25);

/* ---- Must-have Error Alerts ---- */
INSERT INTO #AlertsToCreate (AlertName, MessageID)
VALUES      (N'DBA - Error 823 (I/O Error)',   823)
,           (N'DBA - Error 824 (I/O Error)',   824)
,           (N'DBA - Error 825 (I/O Retry Warning)', 825)
,           (N'DBA - Error 9002 (Log File Full)', 9002)
,           (N'DBA - Error 1105 (Could Not Allocate Space)', 1105)
,           (N'DBA - Error 18456 (Login Failed)', 18456);

/* ---- Performance Condition Alerts (optional but recommended) ----
   NOTE: These use SQL Agent "SQL Server performance condition alert".
   The string format is: 'object|counter|instance|comparison|value'
   Instance can be left blank between pipes when not applicable.
*/
INSERT INTO #AlertsToCreate (AlertName, PerformanceCondition)
VALUES      (N'DBA - Page Life Expectancy < 300', N'SQLServer:Buffer Manager|Page life expectancy||<|300')
,           (N'DBA - TempDB Log Used >= 80%', N'SQLServer:Databases|Percent Log Used|tempdb|>|80');


/* ---- Always On AG Alerts (only if HADR is enabled on this instance) ---- */
IF (SERVERPROPERTY('IsHadrEnabled') = 1)
BEGIN
    INSERT INTO #AlertsToCreate (AlertName, MessageID)
    VALUES      (N'DBA - AG Role Change (1480)', 1480)           -- failover/role change noticed
    ,           (N'DBA - AG Critical: 35264', 35264)             -- AG is offline / failed
    ,           (N'DBA - AG Critical: 35265', 35265)             -- Replica failed
    ,           (N'DBA - AG Critical: 35266', 35266)             -- AG in failed state
    ,           (N'DBA - AG Database Not Synchronizing (976)', 976)
    ,           (N'DBA - AG Database Not Synchronizing (977)', 977)
    ,           (N'DBA - AG Database Not Synchronizing (978)', 978);
END

/* 3) Create/update alerts and add notification to the DBA operator */
DECLARE @AlertName NVARCHAR(256)
,       @Severity  INT
,       @MessageID INT
,       @PerfCond  NVARCHAR(512)
,       @sql       NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT AlertName, Severity, MessageID, PerformanceCondition
    FROM #AlertsToCreate;

OPEN cur;
FETCH NEXT FROM cur INTO @AlertName, @Severity, @MessageID, @PerfCond;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = @AlertName)
    BEGIN
        -- Update existing alert in case thresholds/props changed
        EXEC msdb.dbo.sp_update_alert
                @name                          = @AlertName
       ,        @enabled                       = 1
       ,        @severity                      = @Severity
       ,        @message_id                    = @MessageID
       ,        @include_event_description_in  = 1
       ,        @delay_between_responses       = @DelaySeconds
       ,        @performance_condition         = @PerfCond
       ,        @job_id                        = NULL;
    END
    ELSE
    BEGIN
        -- Create new alert
        EXEC msdb.dbo.sp_add_alert
                @name                          = @AlertName
        ,       @severity                      = @Severity
        ,       @message_id                    = @MessageID
        ,       @include_event_description_in  = 1
        ,       @enabled                       = 1
        ,       @delay_between_responses       = @DelaySeconds
        ,       @performance_condition         = @PerfCond
        ,       @job_id                        = NULL;
    END

    -- Link notification to Operator 'DBA' (email)
    IF NOT EXISTS   (
                    SELECT  1
                    FROM    msdb.dbo.sysalerts          a
                    JOIN    msdb.dbo.sysnotifications   n ON a.id = n.alert_id
                    JOIN    msdb.dbo.sysoperators       o ON o.id = n.operator_id
                    WHERE   a.name = @AlertName 
                    AND     o.name = @OperatorName
                    )
    BEGIN
        EXEC msdb.dbo.sp_add_notification
            @alert_name             = @AlertName
       ,    @operator_name          = @OperatorName
       ,    @notification_method    = 1; -- 1 = E-mail, 2 = Pager, 4 = Net send
    END

    FETCH NEXT FROM cur INTO @AlertName, @Severity, @MessageID, @PerfCond;
END

CLOSE cur;
DEALLOCATE cur;

PRINT 'Alerts ensured and linked to operator "DBA".';
GO

/* 4) (Optional) Failed Job Notifications
   Best practice: configure each *critical* Agent job to email Operator DBA on failure.
   You can enforce a default at job creation time, but retrofitting all jobs requires per-job updates.
   Example per job:
   EXEC msdb.dbo.sp_update_job 
        @job_name = N'Your Job Name',
        @notify_email_operator_name = N'DBA',
        @notify_level_email = 2;  -- 2 = On Failure (1=On Success, 2=On Failure, 3=On Completion)
*/
