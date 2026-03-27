WITH DBSize AS 
(
SELECT		d.database_id
,			d.name
,			CONVERT(DECIMAL(18,2), SUM(mf.size) * 8.0 / 1024 / 1024) AS SizeGB 
FROM		sys.databases		d
JOIN		sys.master_files	mf ON d.database_id = mf.database_id
GROUP BY	d.database_id
,			d.name
)
SELECT		SERVERPROPERTY('ServerName')										AS ServerName
,			CASE CONVERT(CHAR(2), SERVERPROPERTY('ProductVersion'))
					WHEN '16' THEN 'SQL Server 2022'
					WHEN '15' THEN 'SQL Server 2019'
					WHEN '14' THEN 'SQL Server 2017'
					WHEN '13' THEN 'SQL Server 2016'
					WHEN '12' THEN 'SQL Server 2014'
					WHEN '11' THEN 'SQL Server 2012'
					ELSE 'Older Version'
			END																	AS ProductVersion
,			SERVERPROPERTY('ProductLevel')										AS ProductLevel
,			SERVERPROPERTY('LicenseType')										AS LicenceType 
,			SERVERPROPERTY('NumLicenses')										AS LicenceNumber
,			SERVERPROPERTY('Edition')											AS SQLEdition
,			d.name																AS DatabaseName
,			d.state_desc											 			AS [State]
,			d.recovery_model_desc												AS RecoveryModel
,           CASE d.compatibility_level
                WHEN 80  THEN 'SQL Server 2000'
                WHEN 90  THEN 'SQL Server 2005'
                WHEN 100 THEN 'SQL Server 2008/2008 R2'
                WHEN 110 THEN 'SQL Server 2012'
                WHEN 120 THEN 'SQL Server 2014'
                WHEN 130 THEN 'SQL Server 2016'
                WHEN 140 THEN 'SQL Server 2017'
                WHEN 150 THEN 'SQL Server 2019'
                WHEN 160 THEN 'SQL Server 2022'
                ELSE 'Unknown'
            END																	AS CompatibilityLevel
,			IIF(d.is_encrypted = 1, 1, 0)										AS IsTDEEnabled
,			sz.SizeGB															AS DatabaseSizeGB
,			IIF(f.FullDate IS NOT NULL, 1, 0)									AS HasFullBackup
,			f.FullDate															AS LastFullBackup
,			IIF(f.FullDate IS NULL, NULL, DATEDIFF(DAY, f.FullDate, GETDATE())) AS FullAgeDays
,			IIF(i.DiffDate IS NOT NULL, 1, 0)									AS HasDiffBackup
,			i.DiffDate															AS LastDiffBackup
,			IIF(i.DiffDate IS NULL, NULL, DATEDIFF(DAY, i.DiffDate, GETDATE())) AS DiffAgeDays
,			IIF(l.LogDate  IS NOT NULL, 1, 0)									AS HasLogBackup
,			l.LogDate															AS LastLogBackup
,			IIF(l.LogDate IS NULL, NULL, DATEDIFF(DAY, l.LogDate, GETDATE()))	AS LogAgeDays
FROM		sys.databases	d
LEFT JOIN	DBSize			sz	ON sz.database_id = d.database_id
OUTER APPLY (
			SELECT TOP (1)
						bs.backup_finish_date AS FullDate
			FROM		msdb.dbo.backupset bs
			WHERE		bs.database_name	= d.name
			AND			bs.type				= 'D'
			ORDER BY	bs.backup_finish_date DESC
			) f
OUTER APPLY (
			SELECT TOP (1)
						bs.backup_finish_date AS DiffDate
			FROM		msdb.dbo.backupset bs
			WHERE		bs.database_name	= d.name
			AND			bs.type				= 'I'
			ORDER BY	bs.backup_finish_date DESC
			) i
OUTER APPLY (
			SELECT TOP (1)
						bs.backup_finish_date AS LogDate
			FROM		msdb.dbo.backupset bs
			WHERE		bs.database_name	= d.name
			AND			bs.type				= 'L'
			ORDER BY	bs.backup_finish_date DESC
			) l
WHERE		d.name != 'tempdb'
ORDER BY	d.name;






