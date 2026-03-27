/*
    - SIMPLE is wrong if you need point-in-time recovery (PITR) or tight RPO.
    - FULL is wrong if you aren’t taking regular log backups (log will bloat endlessly).
    - BULK_LOGGED is usually temporary for bulk loads; wrong if it’s left on permanently for a DB that needs PITR at all times.

*/

-- Recovery model + last log backup; flags likely problems
WITH last_log AS 
(
SELECT      d.name
,           d.recovery_model_desc
,           MAX(CASE WHEN b.type='L' THEN b.backup_finish_date END)     AS last_log_backup
FROM        sys.databases       d
LEFT JOIN   msdb.dbo.backupset  b ON b.database_name = d.name
GROUP BY    d.name
,           d.recovery_model_desc
)
SELECT      name
,           recovery_model_desc
,           last_log_backup
,           CASE    WHEN recovery_model_desc = 'FULL' AND (last_log_backup IS NULL OR last_log_backup < DATEADD(HOUR,-24,GETDATE()))
                        THEN 'FULL without recent log backups (log growth risk)'
                    WHEN recovery_model_desc = 'SIMPLE'
                        THEN 'SIMPLE (no PITR) — OK only if RPO allows loss since last full/diff'
                    WHEN recovery_model_desc = 'BULK_LOGGED'
                        THEN 'BULK_LOGGED — usually temporary; review PITR requirements'
                    ELSE 'OK'
            END AS finding
FROM        last_log
WHERE       name NOT IN ('tempdb')  -- tempdb is always SIMPLE
ORDER BY    finding DESC
,           name;
