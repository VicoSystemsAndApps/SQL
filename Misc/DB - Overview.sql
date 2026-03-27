CREATE TABLE #FileSize
(
    DBName              NVARCHAR(128)
,   FileName            NVARCHAR(128)
,   PhysicalName        NVARCHAR(128)
,   type_desc           NVARCHAR(128)
,   recovery_model_desc NVARCHAR(128)
,   CurrentSizeMB       VARCHAR(12)
,   FreeSpaceMB         VARCHAR(12)
);
    
INSERT INTO #FileSize
            (dbName, FileName, PhysicalName, type_desc, recovery_model_desc, CurrentSizeMB, FreeSpaceMB)
EXEC        sp_msforeachdb 
            'use [?]; 
             SELECT DB_NAME()                       AS DbName
             ,      df.name                         AS FileName
             ,      df.physical_name                AS PhysicalName
             ,      df.type_desc
             ,      d.recovery_model_desc
             ,      FORMAT(df.size / 128.0, ''N2'') AS CurrentSizeMB
             ,      FORMAT(df.size / 128.0 - CAST(FILEPROPERTY(df.name, ''SpaceUsed'') AS INT) / 128.0, ''N2'') AS FreeSpaceMB
             FROM   sys.database_files df
             JOIN   sys.databases      d   ON d.name = DB_NAME()
             WHERE  type IN (0, 1)
             ';
    
SELECT      * 
FROM        #FileSize
--WHERE       type_desc = 'ROWS'
ORDER by    DBName;
--ORDER BY LEFT(PhysicalName, 1)
    
DROP TABLE #FileSize;

