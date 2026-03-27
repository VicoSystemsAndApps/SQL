/*
	Identify inbound connections (who’s connecting)
	Run this during normal business hours or over time (snapshot regularly).
*/

SELECT		c.client_net_address
,			s.host_name
,			s.program_name
,			s.login_name
,			DB_NAME(s.database_id) AS database_name
,			s.status
,			s.last_request_end_time
FROM		sys.dm_exec_sessions        s
JOIN		sys.dm_exec_connections     c	ON s.session_id = c.session_id
WHERE		s.is_user_process = 1
ORDER BY	s.host_name
,			s.program_name;

-- Linked Servers ----------------------------------------------------------
SELECT	name
,		data_source
,		provider_string
,		provider
,		catalog
FROM	sys.servers
WHERE	is_linked = 1;

-- SQL Mail -----------------------------------------------------------------
EXEC msdb.dbo.sysmail_help_account_sp;
EXEC msdb.dbo.sysmail_help_profile_sp;

-- SQL Agent Connections ----------------------------------------------------
SELECT	j.name AS job_name
,		s.step_name
,		s.command
FROM	msdb.dbo.sysjobsteps	s
JOIN	msdb.dbo.sysjobs		j ON s.job_id = j.job_id
WHERE	s.command LIKE '%SERVER=%' 
OR		s.command LIKE '%Data Source=%';


-- Query usage by login or host ---------------------------------------------
SELECT		login_name
,			COUNT(1)	AS connections
,			host_name
FROM		sys.dm_exec_sessions
WHERE		is_user_process = 1
GROUP BY	login_name
,			host_name;


-- Run on VM in PS -------------------------------------------------------------
-- Checks for DNS, CNAME or SQL Alias usage
/*
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo"
Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer\Client\ConnectTo"
*/

-- Firewall and Ports -------------------------------------------------------
EXEC xp_readerrorlog 0, 1, N'Server is listening on';
