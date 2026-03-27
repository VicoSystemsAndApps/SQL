-- Red flag: No backups, or stale backups.

-- Last full, diff, and log backups
SELECT		d.name  AS DatabaseName
,			MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END) AS LastFullBackup
,			MAX(CASE WHEN b.type = 'I' THEN b.backup_finish_date END) AS LastDiffBackup
,			MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END) AS LastLogBackup
FROM		sys.databases		d
LEFT JOIN	msdb.dbo.backupset	b ON b.database_name = d.name
GROUP BY	d.name
ORDER BY	d.name;