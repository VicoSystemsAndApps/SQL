SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @TopPerDb   INT          = 50      -- only check the top-N largest indexes per DB
,       @MinPages   INT          = 1000    -- ignore tiny indexes
,       @MinFrag    DECIMAL(5,2) = 15.0    -- show only > this fragmentation
,       @PauseMs    INT          = 250     -- short pause between DBs to be nice
,       @UseSampled BIT          = 1;      -- 1 = SAMPLED, 0 = LIMITED

BEGIN TRY
    IF OBJECT_ID('tempdb..#Index') IS NOT NULL DROP TABLE #Index;

    CREATE TABLE #Index
    (
        DatabaseName    SYSNAME
    ,   SchemaName      SYSNAME
    ,   TableName       SYSNAME
    ,   IndexName       SYSNAME
    ,   IndexType       NVARCHAR(60)
    ,   AvgPageFrag     DECIMAL(10,2)
    ,   PageCounts      BIGINT
    );

    DECLARE @db     SYSNAME
    ,       @sql    NVARCHAR(MAX)
    ,       @mode   NVARCHAR(20) = IIF(@UseSampled = 1, N'SAMPLED', N'LIMITED');

    DECLARE dbs CURSOR FAST_FORWARD FOR
    SELECT  name
    FROM    sys.databases
    WHERE   name                NOT IN ('master','model','msdb','tempdb','SSISDB')
    AND     state_desc          = 'ONLINE'
    AND     source_database_id  IS NULL; -- no snapshots

    OPEN dbs;
    FETCH NEXT FROM dbs INTO @db;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'
            USE ' + QUOTENAME(@db) + N';
            WITH big_ix AS (
                SELECT      TOP(' + CAST(@TopPerDb AS nvarchar(10)) + N')
                            p.object_id
                ,           p.index_id
                ,           SUM(p.used_page_count) AS page_count
                FROM        sys.dm_db_partition_stats AS p
                WHERE       p.index_id > 0 -- ignore heaps
                GROUP BY    p.object_id
                ,           p.index_id
                HAVING      SUM(p.used_page_count) >= ' + CAST(@MinPages AS nvarchar(20)) + N'
                ORDER BY    SUM(p.used_page_count) DESC
            )
            INSERT INTO #Index
                        (DatabaseName, SchemaName, TableName, IndexName, IndexType, AvgPageFrag, PageCounts)
            SELECT      DB_NAME()                                                           AS DatabaseName
            ,           sch.name                                                            AS SchemaName
            ,           OBJECT_NAME(b.object_id)                                            AS TableName
            ,           ix.name                                                             AS IndexName
            ,           ips.index_type_desc                                                 AS IndexType
            ,           CONVERT(decimal(10,2), ROUND(ips.avg_fragmentation_in_percent,2))   AS AvgPageFrag
            ,           ips.page_count                                                      AS PageCounts
            FROM        big_ix          b
            JOIN        sys.indexes     ix  ON  b.object_id = ix.object_id 
                                            AND b.index_id  = ix.index_id
            JOIN        sys.tables      t   ON  t.object_id = b.object_id
            JOIN        sys.schemas     sch ON sch.schema_id = t.schema_id
            CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(), b.object_id, b.index_id, NULL, ''' + @mode + N''') AS ips
            WHERE       ix.is_hypothetical                  = 0
            AND         ix.is_disabled                      = 0
            AND         ips.alloc_unit_type_desc            = ''IN_ROW_DATA''
            AND         ips.avg_fragmentation_in_percent    >= ' + CAST(@MinFrag AS nvarchar(20)) + N'
            OPTION      (MAXDOP 1, RECOMPILE);';

        BEGIN TRY
            EXEC sys.sp_executesql @sql;
        END TRY

        BEGIN CATCH
            -- swallow per-DB errors and keep going
            PRINT CONCAT('Skipped ', @db, ' due to: ', ERROR_MESSAGE());
        END CATCH;

        WAITFOR DELAY '00:00:01'; -- 1 second


        FETCH NEXT FROM dbs INTO @db;
    END

    CLOSE dbs; DEALLOCATE dbs;

    SELECT      *
    FROM        #Index
    ORDER BY    AvgPageFrag DESC
    ,           PageCounts DESC;

    DROP TABLE #Index;
END TRY
BEGIN CATCH
    IF OBJECT_ID('tempdb..#Index') IS NOT NULL DROP TABLE #Index;
    THROW;
END CATCH;


--ALTER INDEX ALL ON dbo.ih_secure_chg REBUILD