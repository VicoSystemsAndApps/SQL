-- Creates SQL for Agent Job Operators

USE msdb;
GO

SELECT	'EXEC msdb.dbo.sp_add_operator @name = N''' + name + ''', ' +
		'@enabled = ' + CAST(enabled AS VARCHAR(1)) + ', ' +
		'@email_address = N''' + ISNULL(email_address,'') + ''', ' +
		'@pager_address = N''' + ISNULL(pager_address,'') + ''', ' +
		'@weekday_pager_start_time = ' + CAST(weekday_pager_start_time AS VARCHAR(10)) + ', ' +
		'@weekday_pager_end_time = ' + CAST(weekday_pager_end_time AS VARCHAR(10)) + ';'		AS [--CreateOperatorSQL]
FROM	msdb.dbo.sysoperators;
