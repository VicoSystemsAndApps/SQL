-- Version and Build
SELECT	SERVERPROPERTY('Edition')			AS edition
,		SERVERPROPERTY('ProductVersion')	AS product_version
,		SERVERPROPERTY('ProductLevel')		AS product_level -- RTM, SP1, SP2, etc.
,		@@VERSION							AS server_version;

-- Transparent Data Encryption (TDE) 
SELECT		d.name					AS database_name
,			dek.encryption_state
FROM		sys.databases					d
LEFT JOIN	sys.dm_database_encryption_keys dek	ON d.database_id = dek.database_id
WHERE		dek.database_id IS NOT NULL;   -- any row here means TDE is/was enabled

-- Availability Groups (AGs)
SELECT	SERVERPROPERTY('IsHadrEnabled') AS HADR_on;

SELECT	ag.name
,		ag.is_distributed
,		dbcs.database_name
FROM	sys.availability_groups				ag
JOIN	sys.availability_databases_cluster	dbcs ON ag.group_id = dbcs.group_id;

-- Resource Governor
SELECT	is_enabled  AS ResourceGov
FROM	sys.resource_governor_configuration;

-- Memory-optimized filegroups present?
-- Standard (2016 SP1+) supports it but with limits; pre-SP1 it was Enterprise-only. Either way, you need to know if you have it.
SELECT	name
,		type_desc 
FROM	sys.filegroups 
WHERE	type = 'FX';

-- Any memory-optimized tables?
SELECT	OBJECT_SCHEMA_NAME(object_id)
,		name
FROM	sys.tables
WHERE	is_memory_optimized = 1;

-- PolyBase Engine is Enterprise-only in 2016. If you rely on external tables, you’ll lose that capability on 2016 Standard.
SELECT	* 
FROM	sys.external_tables;      -- presence suggests PolyBase use

-- Enterprise-only. Drop any snapshots before you migrate.
SELECT name, source_database_id
FROM sys.databases
WHERE source_database_id IS NOT NULL;   -- these are snapshots


-- Max cores: Standard 2016 = up to 24 cores (or 4 sockets, whichever is lower).
SELECT	COUNT(*) AS online_schedulers
FROM	sys.dm_os_schedulers
WHERE	scheduler_id	< 255 
AND		is_online		= 1 
AND		status			= 'VISIBLE ONLINE';

-- Memory (max 128GB for Standard)
SELECT	name
,		value
,		value_in_use
FROM	sys.configurations
WHERE	name = 'max server memory (MB)';

SELECT	physical_memory_kb/1024/1024 AS server_RAM_GB
FROM	sys.dm_os_sys_info;

-- Online index operations aren’t available on 2016 Standard. Search Agent jobs/maintenance plans for ONLINE = ON.
SELECT	j.name AS job_name
,		s.step_id
,		s.command
FROM	msdb.dbo.sysjobsteps	s
JOIN	msdb.dbo.sysjobs		j ON j.job_id = s.job_id
WHERE	s.command LIKE '%ONLINE = ON%';

-- Logins (SQL auth)
SELECT	name
,		type_desc
,		sid 
FROM	sys.server_principals 
WHERE	type IN ('S','U') 
AND		name NOT LIKE '##%';

-- Linked servers
SELECT	* 
FROM	sys.servers 
WHERE	is_linked = 1;

-- Credentials
SELECT	name 
FROM	sys.credentials;

-- Agent jobs
SELECT	name 
FROM	msdb.dbo.sysjobs;







