SET NOCOUNT ON;

-- Temp table to collect results across user databases
IF OBJECT_ID('tempdb..#FileIO') IS NOT NULL DROP TABLE #FileIO;
CREATE TABLE #FileIO
(
    DatabaseName        sysname
,   LogicalName         sysname
,   FileType            nvarchar(20)
--,   PhysicalName        nvarchar(260)
,   FileSizeMB          decimal(19,2)
,   SpaceUsedMB         decimal(19,2)
,   FreeSpaceMB         decimal(19,2)
,   FreePct             decimal(5,2)
,   NumReads            bigint
,   NumWrites           bigint
,   AvgReadLatency_ms   decimal(19,2)
,   AvgWriteLatency_ms  decimal(19,2)
--,   DatabaseTotalSizeMB decimal(19,2)
);

DECLARE @db  sysname
,       @sql nvarchar(max);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT  name
    FROM    sys.databases
    WHERE   database_id > 4       -- user DBs only
    AND     state = 0;            -- online

    OPEN c; FETCH NEXT FROM c INTO @db;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'
            USE ' + QUOTENAME(@db) + N';

            WITH fileinfo AS (
                SELECT  DB_NAME()                              AS DatabaseName
                ,       df.file_id
                ,       df.name                                AS LogicalName
                ,       df.type_desc                           AS FileType
                ,       df.physical_name                       AS PhysicalName
                ,       CAST(df.size * 8.0 / 1024.0 AS DECIMAL(19,2))                               AS FileSizeMB
                ,       CAST(FILEPROPERTY(df.name, ''SpaceUsed'') * 8.0 / 1024.0 AS DECIMAL(19,2))  AS SpaceUsedMB
                ,       CAST((df.size - FILEPROPERTY(df.name, ''SpaceUsed'')) * 8.0 / 1024.0 AS DECIMAL(19,2)) AS FreeSpaceMB
                FROM    sys.database_files AS df
            ),
            io AS (
                SELECT  vfs.file_id
                ,       vfs.num_of_reads      AS NumReads
                ,       vfs.num_of_writes     AS NumWrites
                ,       CAST(vfs.io_stall_read_ms  / NULLIF(vfs.num_of_reads,0)  AS DECIMAL(19,2)) AS AvgReadLatency_ms
                ,       CAST(vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes,0) AS DECIMAL(19,2)) AS AvgWriteLatency_ms
                FROM    sys.dm_io_virtual_file_stats(DB_ID(), NULL) AS vfs
            ),
            final AS (
                SELECT      f.DatabaseName
                ,           f.LogicalName
                ,           f.FileType
                --,           f.PhysicalName
                ,           f.FileSizeMB
                ,           f.SpaceUsedMB
                ,           f.FreeSpaceMB
                ,           CAST(CASE WHEN f.FileSizeMB > 0 THEN (f.FreeSpaceMB / f.FileSizeMB) * 100.0 END AS DECIMAL(5,2)) AS FreePct
                ,           i.NumReads
                ,           i.NumWrites
                ,           i.AvgReadLatency_ms
                ,           i.AvgWriteLatency_ms
                --,           SUM(f.FileSizeMB) OVER () AS DatabaseTotalSizeMB
                FROM        fileinfo f
                LEFT JOIN   io i ON i.file_id = f.file_id
            )
            SELECT  *
            FROM    final;
        ';

        INSERT INTO #FileIO
        (
            DatabaseName, LogicalName, FileType, --PhysicalName,
            FileSizeMB, SpaceUsedMB, FreeSpaceMB, FreePct,
            NumReads, NumWrites, AvgReadLatency_ms, AvgWriteLatency_ms
            --DatabaseTotalSizeMB
        )
        EXEC sys.sp_executesql @sql;

        FETCH NEXT FROM c INTO @db;
    END

CLOSE c; DEALLOCATE c;

-- Final report
SELECT      *
FROM        #FileIO
ORDER BY    DatabaseName, FileType, LogicalName;
