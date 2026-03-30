/* Script to check backup information
20250402	jane.palmer		created
*/

SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--/*Date of last backup*/
--SELECT sdb.Name AS DatabaseName,
-- COALESCE(CONVERT(VARCHAR(12), MAX(bus.backup_finish_date), 101),'-') AS LastBackUpTime
-- FROM sys.sysdatabases sdb
-- LEFT OUTER JOIN msdb.dbo.backupset bus ON bus.database_name = sdb.name
-- GROUP BY sdb.Name

 /*Detailed backup information. Use a WHERE clause to filter*/
 SELECT  
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   msdb.dbo.backupset.database_name,  
   msdb.dbo.backupset.backup_start_date,  
   msdb.dbo.backupset.backup_finish_date, 
   DATEDIFF(mi,backup_start_date, backup_finish_date) RunTimeMins,
   DATEDIFF(hh,backup_start_date,backup_finish_date) RunTimeHrs,
   CASE msdb..backupset.type  
       WHEN 'D' THEN 'Database'  
       WHEN 'L' THEN 'Log'  
	   ELSE 'Diff'
   END AS backup_type, 
   msdb.dbo.backupset.is_copy_only,
   CAST(msdb.dbo.backupset.backup_size/1024.0/1024 AS DECIMAL(10, 2)) AS BackupSizeMB,
   CAST(msdb.dbo.backupset.compressed_backup_size/1024.0/1024 AS DECIMAL(10, 2)) AS compressed_backup_size,
   msdb.dbo.backupmediafamily.physical_device_name,   
   msdb.dbo.backupset.name AS backupset_name, 
   msdb.dbo.backupset.description 
FROM   msdb.dbo.backupmediafamily  
   INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id  
--WHERE database_name = 'DBNAME'
ORDER BY backup_finish_date DESC