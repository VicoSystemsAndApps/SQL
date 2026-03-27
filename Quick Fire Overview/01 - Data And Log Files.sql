/*
    master → Holds instance metadata; if C: fails, SQL won’t start.
    msdb → Critical for SQL Agent jobs, backups, and history; space issues on C: can stop scheduling.
    model → Template for new DBs; corruption or space issues affect all new DB creation.
    tempdb → Heavy IO use; if on C:, competes with OS and risks performance bottlenecks.
    SSISDB → User DB for SSIS catalog; loss or corruption impacts deployments and package runs.

    Red flags:
        Tiny growth increments (1MB, 10%)
        Frequent autogrowth events in logs
*/

-- Data & log files with sizes and growth settings
SELECT      db_name(mf.database_id)                                                         AS DatabaseName
,           d.recovery_model_desc                                                           AS RecoveryModel
,           mf.name                                                                         AS FileName
,           mf.physical_name
,           type_desc                                                                       AS FileType
,           CONVERT(VARCHAR(20), FORMAT(CONVERT(BIGINT, size) * 8 / 1024, 'N0')) + ' MB'    AS SizeMB
,           IIF(is_percent_growth = 1
                , CAST(growth AS VARCHAR(20)) + '%'
                , CONVERT(VARCHAR(20), FORMAT(growth * 8 / 1024, 'N0')) + ' MB'
            )                                                                               AS GrowthSetting
FROM        sys.master_files    mf
JOIN        sys.databases       d   ON mf.database_id = d.database_id
ORDER BY    DatabaseName
,           FileType;

-- DBCC CHECKDB ('SDSSequelWorking');

--DBCC SHRINKFILE (N'MSDBData' , 3584);
--DBCC SHRINKFILE (N'SQLMAINT_log' , 1920);
