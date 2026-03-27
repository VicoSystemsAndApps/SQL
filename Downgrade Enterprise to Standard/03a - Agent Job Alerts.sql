-- Creats alerts in a sql script
USE msdb;
GO
SET NOCOUNT ON;

SELECT  'EXEC msdb.dbo.sp_add_alert ' +
        '@name = N''' + a.name + ''', ' +
        '@message_id = ' + CAST(a.message_id AS VARCHAR(10)) + ', ' +
        '@severity = ' + CAST(a.severity AS VARCHAR(10)) + ', ' +
        '@enabled = ' + CAST(a.enabled AS VARCHAR(10)) + ', ' +
        '@delay_between_responses = ' + CAST(a.delay_between_responses AS VARCHAR(10)) + ', ' +
        '@include_event_description = ' + CAST(a.include_event_description AS VARCHAR(10)) + ', ' +
        '@database_name = N''' + ISNULL(a.database_name,'') + ''', ' +
        '@event_description_keyword = N''' + ISNULL(a.event_description_keyword,'') + ''', ' +
        '@performance_condition = N''' + ISNULL(a.performance_condition,'') + ''';'                 AS [--CreateAlertSQL]
FROM    msdb.dbo.sysalerts a;


-- Reattach alert → operator notifications (run after operators exist)
SELECT  'EXEC msdb.dbo.sp_add_notification @alert_name = N''' + a.name + ''', ' +
        '@operator_name = N''' + o.name + ''', ' +
        '@notification_method = ' + CAST(n.notification_method AS VARCHAR(10)) + ';'    AS [--AddNotificationSQL]
FROM    msdb.dbo.sysalerts          a
JOIN    msdb.dbo.sysnotifications   n ON a.id           = n.alert_id
JOIN    msdb.dbo.sysoperators       o ON n.operator_id  = o.id;
GO
