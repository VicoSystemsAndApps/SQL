/* Find backup location*/

SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT  
    database_name,  
    backup_finish_date,  
    CASE msdb..backupset.type  
        WHEN 'D' THEN 'Database'  
        WHEN 'L' THEN 'Log'  
    END AS backup_type,  
    physical_device_name,  
 device_type  
FROM msdb.dbo.backupmediafamily  
INNER JOIN msdb.dbo.backupset  
    ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id  
--WHERE (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 1)  
ORDER BY database_name,backup_finish_date 