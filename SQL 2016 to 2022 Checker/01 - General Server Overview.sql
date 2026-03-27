--------------------------------------------------------------------------------
-- SQL SERVER BASELINE AUDIT
--
-- Purpose:
--   General SQL Server estate audit to identify configuration, workload,
--   code-pattern, and feature-usage findings before upgrade, migration,
--   or tuning work.
--
-- Scope:
--   - All ONLINE user databases
--   - Read-only checks only
--   - Mixture of server-level and per-database findings
--
-- Notes:
--   - This is a broad baseline script, not only an upgrade-risk script
--   - Some findings are operational tuning items rather than migration blockers
--   - Output should be interpreted as a review list, not automatic remediation
--------------------------------------------------------------------------------

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#DbList') IS NOT NULL DROP TABLE #DbList;
CREATE TABLE #DbList
(
    dbname sysname NOT NULL PRIMARY KEY
);

INSERT  #DbList (dbname)
SELECT  name
FROM    sys.databases
WHERE   database_id > 4
AND     state_desc = 'ONLINE'
AND     source_database_id IS NULL;

/*-------------------------------------------------------------------------------
1) Server inventory

What are we querying?
  Basic server-level identity and platform details such as version, edition,
  clustering, HADR status, and audit timestamp.

Why it matters:
  Establishes the baseline environment and confirms where the audit was run.

Red flags:
  - Unexpected edition or version
  - HA/cluster features enabled when not expected
  - Environment not matching documented design
-------------------------------------------------------------------------------*/
SELECT  'Query No 1'                            AS check_number
,       @@SERVERNAME                            AS server_name
,       SERVERPROPERTY('MachineName')           AS machine_name
,       SERVERPROPERTY('ServerName')            AS server_property_name
,       SERVERPROPERTY('Edition')               AS edition
,       SERVERPROPERTY('ProductVersion')        AS product_version
,       SERVERPROPERTY('ProductLevel')          AS product_level
,       SERVERPROPERTY('ProductMajorVersion')   AS product_major_version
,       SERVERPROPERTY('EngineEdition')         AS engine_edition
,       SERVERPROPERTY('IsClustered')           AS is_clustered
,       SERVERPROPERTY('IsHadrEnabled')         AS is_hadr_enabled
,       GETDATE()                               AS audit_time;

/*-------------------------------------------------------------------------------
2) Database inventory

What are we querying?
  High-level database settings including compatibility level, recovery model,
  containment, page verification, stats settings, Query Store flag, and state.

Why it matters:
  Gives a quick estate-wide view of database configuration and highlights
  inconsistencies between databases.

Red flags:
  - Unexpected compatibility-level mix
  - Auto-stats disabled without good reason
  - PAGE_VERIFY not set as expected
  - Databases not ONLINE or not in expected state
-------------------------------------------------------------------------------*/
SELECT      'Query No 2'                    AS check_number
,           d.name
,           d.compatibility_level
,           d.recovery_model_desc
,           d.containment_desc
,           d.page_verify_option_desc
,           d.is_auto_create_stats_on
,           d.is_auto_update_stats_on
,           d.is_auto_update_stats_async_on
,           d.is_query_store_on
,           d.state_desc
FROM        sys.databases d
WHERE       d.database_id > 4
ORDER BY    d.name;

-------------------------------------------------------------------------------
-- temp tables for collected data
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#QueryStoreStatus') IS NOT NULL DROP TABLE #QueryStoreStatus;
CREATE TABLE #QueryStoreStatus
(
    database_name                   SYSNAME
,   actual_state_desc               NVARCHAR(60) NULL
,   desired_state_desc              NVARCHAR(60) NULL
,   readonly_reason                 INT NULL
,   current_storage_size_mb         BIGINT NULL
,   max_storage_size_mb             BIGINT NULL
,   interval_length_minutes         BIGINT NULL
,   stale_query_threshold_days      BIGINT NULL
,   query_capture_mode_desc         NVARCHAR(60) NULL
,   wait_stats_capture_mode_desc    NVARCHAR(60) NULL
);

IF OBJECT_ID('tempdb..#DbScopedConfigs') IS NOT NULL DROP TABLE #DbScopedConfigs;
CREATE TABLE #DbScopedConfigs
(
    database_name       SYSNAME
,   config_name         SYSNAME
,   value               SQL_VARIANT NULL
,   value_for_secondary SQL_VARIANT NULL
,   is_value_default    BIT NULL
);

IF OBJECT_ID('tempdb..#MissingIndexes') IS NOT NULL DROP TABLE #MissingIndexes;
CREATE TABLE #MissingIndexes
(
    database_name           SYSNAME
,   table_name              NVARCHAR(517)
,   user_seeks              BIGINT NULL
,   user_scans              BIGINT NULL
,   avg_total_user_cost     FLOAT NULL
,   avg_user_impact         FLOAT NULL
,   equality_columns        NVARCHAR(MAX) NULL
,   inequality_columns      NVARCHAR(MAX) NULL
,   included_columns        NVARCHAR(MAX) NULL
);

IF OBJECT_ID('tempdb..#HeapIssues') IS NOT NULL DROP TABLE #HeapIssues;
CREATE TABLE #HeapIssues
(
    database_name                   SYSNAME
,   schema_name                     SYSNAME NULL
,   table_name                      SYSNAME NULL
,   avg_fragmentation_in_percent    FLOAT NULL
,   forwarded_record_count          BIGINT NULL
,   page_count                      BIGINT NULL
);

IF OBJECT_ID('tempdb..#ModulePatterns') IS NOT NULL DROP TABLE #ModulePatterns;
CREATE TABLE #ModulePatterns
(
    database_name       SYSNAME
,   schema_name         SYSNAME NULL
,   object_name         SYSNAME NULL
,   type_desc           NVARCHAR(60) NULL
,   matched_pattern     NVARCHAR(100) NULL
);

IF OBJECT_ID('tempdb..#TopQueryStoreQueries') IS NOT NULL DROP TABLE #TopQueryStoreQueries;
CREATE TABLE #TopQueryStoreQueries
(
    database_name       SYSNAME
,   query_id            BIGINT NULL
,   plan_id             BIGINT NULL
,   executions          BIGINT NULL
,   avg_duration_ms     FLOAT NULL
,   avg_cpu_ms          FLOAT NULL
,   avg_logical_reads   FLOAT NULL
,   last_execution_time DATETIME2 NULL
,   query_sql_text      NVARCHAR(MAX) NULL
);

/*-------------------------------------------------------------------------------
3a..f) Collect per-database details 

What are we doing?
  Looping through all ONLINE user databases and collecting a common set of
  findings into temp tables for later review.

Why it matters:
  Ensures the audit is repeatable and consistent across the whole instance.

Red flags:
  - Errors against individual databases
  - Missing catalog views where expected
  - Databases skipped due to state or access issues
-------------------------------------------------------------------------------*/
DECLARE @db     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT dbname
FROM #DbList
ORDER BY dbname;

OPEN cur;
FETCH NEXT FROM cur INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    /*----------------------------------------------------------------------------
    Query Store status
    
    What are we querying?
      Current Query Store operational and storage settings for each database.
    
    Why it matters:
      Query Store is key for workload baselining, regression analysis, and
      identifying expensive queries over time.
    
    Red flags:
      - Query Store OFF
      - Query Store READ_ONLY unexpectedly
      - Small storage cap for busy databases
      - Wait stats capture not enabled where expected
    ----------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = ''database_query_store_options'')
    BEGIN
        INSERT  #QueryStoreStatus
        (   
            database_name
        ,   actual_state_desc
        ,   desired_state_desc
        ,   readonly_reason
        ,   current_storage_size_mb
        ,   max_storage_size_mb
        ,   interval_length_minutes
        ,   stale_query_threshold_days
        ,   query_capture_mode_desc
        ,   wait_stats_capture_mode_desc
        )
        SELECT  DB_NAME()
        ,       actual_state_desc
        ,       desired_state_desc
        ,       readonly_reason
        ,       current_storage_size_mb
        ,       max_storage_size_mb
        ,       interval_length_minutes
        ,       stale_query_threshold_days
        ,       query_capture_mode_desc
        ,       wait_stats_capture_mode_desc
        FROM    sys.database_query_store_options;
    END;
    ';
    EXEC sys.sp_executesql @sql;

    /*----------------------------------------------------------------------------
    Database scoped configs
    
    What are we querying?
      Database-level optimizer and execution settings such as legacy CE,
      optimizer hotfixes, parameter sniffing, and MAXDOP.
    
    Why it matters:
      These can materially change plan choice and query behaviour independently
      of server-level defaults.
    
    Red flags:
      - LEGACY_CARDINALITY_ESTIMATION enabled
      - PARAMETER_SNIFFING disabled
      - Non-default MAXDOP without clear reason
      - Optimizer settings differing unexpectedly across databases
    ----------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = ''database_scoped_configurations'')
    BEGIN
        INSERT  #DbScopedConfigs
        (       database_name
        ,       config_name
        ,       value
        ,       value_for_secondary
        ,       is_value_default
        )
        SELECT  DB_NAME()
        ,       name
        ,       value
        ,       value_for_secondary
        ,       is_value_default
        FROM    sys.database_scoped_configurations
        WHERE   name IN (   ''LEGACY_CARDINALITY_ESTIMATION''
                        ,   ''QUERY_OPTIMIZER_HOTFIXES''
                        ,   ''PARAMETER_SNIFFING''
                        ,   ''MAXDOP''
                        );
    END;
    ';
    EXEC sys.sp_executesql @sql;

    /*----------------------------------------------------------------------------
    Missing index hints
    
    What are we querying?
      SQL Server missing-index recommendations derived from workload activity.
    
    Why it matters:
      Highlights tables and predicates where additional indexing may reduce
      query cost or improve access paths.
    
    Red flags:
      - Large number of high-impact suggestions
      - Repeated recommendations against heavily used tables
      - Signs of weak or inconsistent indexing strategy
    
    Notes:
      - Advisory only; do not create indexes blindly
      - Recommendations should be reviewed against existing indexes and workload
    ----------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT  #MissingIndexes
    (       database_name
    ,       table_name
    ,       user_seeks
    ,       user_scans
    ,       avg_total_user_cost
    ,       avg_user_impact
    ,       equality_columns
    ,       inequality_columns
    ,       included_columns
    )
    SELECT TOP(20)  DB_NAME(mid.database_id)
    ,               QUOTENAME(OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id)) + ''.'' +
                        QUOTENAME(OBJECT_NAME(mid.object_id, mid.database_id))
    ,               migs.user_seeks
    ,               migs.user_scans
    ,               migs.avg_total_user_cost
    ,               migs.avg_user_impact
    ,               mid.equality_columns
    ,               mid.inequality_columns
    ,               mid.included_columns
    FROM            sys.dm_db_missing_index_group_stats migs
    JOIN            sys.dm_db_missing_index_groups      mig ON migs.group_handle    = mig.index_group_handle
    JOIN            sys.dm_db_missing_index_details     mid ON mig.index_handle     = mid.index_handle
    WHERE           mid.database_id = DB_ID()
    ORDER BY        migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC;
    ';
    EXEC sys.sp_executesql @sql;

    /*----------------------------------------------------------------------------
    Heap forwarded records
    
    What are we querying?
      Heap tables with forwarded records and fragmentation characteristics.
    
    Why it matters:
      Forwarded records increase I/O and can degrade performance, especially on
      frequently updated heap tables.
    
    Red flags:
      - High forwarded_record_count
      - Large heaps with significant forwarding
      - Repeated issues on actively queried tables
    
    Notes:
      - This is mainly an operational tuning check, not an upgrade-specific risk
    ----------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT  #HeapIssues
    (       database_name
    ,       schema_name
    ,       table_name
    ,       avg_fragmentation_in_percent
    ,       forwarded_record_count
    ,       page_count
    )
    SELECT  DB_NAME()
    ,       OBJECT_SCHEMA_NAME(ps.object_id)
    ,       OBJECT_NAME(ps.object_id)
    ,       ps.avg_fragmentation_in_percent
    ,       ps.forwarded_record_count
    ,       ps.page_count
    FROM    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''SAMPLED'') AS ps
    WHERE   ps.index_type_desc          = ''HEAP''
    AND     ps.forwarded_record_count   > 0;
    ';
    EXEC sys.sp_executesql @sql;

    /*----------------------------------------------------------------------------
    Code review patterns
    
    What are we querying?
      Module definitions for common SQL patterns such as NOLOCK, RECOMPILE,
      CURSOR usage, SELECT *, and FOR XML PATH string concatenation.
    
    Why it matters:
      These patterns can indicate legacy coding styles, maintainability issues,
      or performance-related workarounds worth reviewing.
    
    Red flags:
      - Heavy NOLOCK usage
      - Frequent OPTION (RECOMPILE)
      - Cursor-heavy procedural logic
      - Widespread SELECT *
      - Older string concatenation patterns still common
    
    Notes:
      - These are review flags, not proof of a problem
    ----------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT  #ModulePatterns 
            (   database_name
            ,   schema_name
            ,   object_name
            ,   type_desc
            ,   matched_pattern
            )
    SELECT  DB_NAME()
    ,       OBJECT_SCHEMA_NAME(sm.object_id)
    ,       OBJECT_NAME(sm.object_id)
    ,       o.type_desc
    ,       ''NOLOCK''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o   ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%WITH (NOLOCK)%''

    UNION ALL
    SELECT  DB_NAME()
    ,       OBJECT_SCHEMA_NAME(sm.object_id)
    ,       OBJECT_NAME(sm.object_id)
    ,       o.type_desc
    ,       ''OPTION (RECOMPILE)''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o    ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%OPTION (RECOMPILE)%''

    UNION ALL

    SELECT  DB_NAME()
    ,       OBJECT_SCHEMA_NAME(sm.object_id)
    ,       OBJECT_NAME(sm.object_id)
    ,       o.type_desc
    ,       ''CURSOR''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o   ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%CURSOR%''

    UNION ALL

    SELECT  DB_NAME()
    ,       OBJECT_SCHEMA_NAME(sm.object_id)
    ,       OBJECT_NAME(sm.object_id)
    ,       o.type_desc
    ,       ''SELECT *''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%SELECT *%''

    UNION ALL

    SELECT  DB_NAME()
    ,       OBJECT_SCHEMA_NAME(sm.object_id)
    ,       OBJECT_NAME(sm.object_id)
    ,       o.type_desc
    ,       ''FOR XML PATH / string concat pattern''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o   ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%FOR XML PATH(%'';
    ';
    EXEC sys.sp_executesql @sql;

    /*----------------------------------------------------------------------------
    Top Query Store queries
    
    What are we querying?
      Highest-duration queries captured in Query Store for each database,
      including executions, CPU, logical reads, and last execution time.
    
    Why it matters:
      Helps prioritise which queries are most expensive and most likely to
      deserve investigation or tuning.
    
    Red flags:
      - Very high average duration
      - High CPU or logical reads
      - Frequently executed expensive queries
      - Recent execution of consistently costly statements
    
    Notes:
      - Only populated where Query Store exists and contains data
    ----------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = ''query_store_query'')
        AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state_desc IN (''READ_WRITE'', ''READ_ONLY''))
    BEGIN
        WITH q AS
        (   
        SELECT      qsq.query_id
        ,           qsp.plan_id
        ,           SUM(rs.count_executions)                        AS executions
        ,           AVG(CONVERT(float, rs.avg_duration)) / 1000.0   AS avg_duration_ms
        ,           AVG(CONVERT(float, rs.avg_cpu_time)) / 1000.0   AS avg_cpu_ms
        ,           AVG(CONVERT(float, rs.avg_logical_io_reads))    AS avg_logical_reads
        ,           MAX(rs.last_execution_time)                     AS last_execution_time
        FROM        sys.query_store_query           qsq
        JOIN        sys.query_store_plan            qsp ON qsq.query_id = qsp.query_id
        JOIN        sys.query_store_runtime_stats   rs  ON qsp.plan_id  = rs.plan_id
        GROUP BY    qsq.query_id
        ,           qsp.plan_id
        )
        INSERT #TopQueryStoreQueries
        (       database_name
        ,       query_id
        ,       plan_id
        ,       executions
        ,       avg_duration_ms
        ,       avg_cpu_ms
        ,       avg_logical_reads
        ,       last_execution_time
        ,       query_sql_text
        )
        SELECT TOP (20) DB_NAME()
        ,               q.query_id
        ,               q.plan_id
        ,               q.executions
        ,               q.avg_duration_ms
        ,               q.avg_cpu_ms
        ,               q.avg_logical_reads
        ,               q.last_execution_time
        ,               qt.query_sql_text
        FROM            q
        JOIN            sys.query_store_query       qsq ON q.query_id           = qsq.query_id
        JOIN            sys.query_store_query_text  qt  ON qsq.query_text_id    = qt.query_text_id
        ORDER BY        q.avg_duration_ms DESC;
    END;
    ';
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM cur INTO @db;
END

CLOSE cur;
DEALLOCATE cur;


/*-------------------------------------------------------------------------------
5) Results

What are we doing?
  Returning the consolidated outputs gathered during the audit loop.

Why it matters:
  Presents a reviewable summary of findings across all databases in one place.

Red flags:
  - Findings should be interpreted in context; some indicate configuration
    risk, others operational tuning opportunities, and others code debt
-------------------------------------------------------------------------------*/

-- Query Store status
SELECT      'Query No 3a' AS check_number
,           database_name
,           actual_state_desc
,           desired_state_desc
,           readonly_reason
,           current_storage_size_mb
,           max_storage_size_mb
,           interval_length_minutes
,           stale_query_threshold_days
,           query_capture_mode_desc
,           wait_stats_capture_mode_desc
FROM        #QueryStoreStatus
ORDER BY    database_name;

-- Database scoped configs
SELECT      'Query No 3b' AS check_number
,           database_name
,           config_name
,           value
,           value_for_secondary
,           is_value_default
FROM        #DbScopedConfigs
ORDER BY    database_name
,           config_name;

-- Missing index hints
SELECT      'Query No 3c' AS check_number
,           database_name
,           table_name
,           user_seeks
,           user_scans
,           avg_total_user_cost
,           avg_user_impact
,           equality_columns
,           inequality_columns
,           included_columns
FROM        #MissingIndexes
ORDER BY    database_name, (avg_total_user_cost * avg_user_impact * (user_seeks + user_scans)) DESC;

-- Heap issues
SELECT      'Query No 3d' AS check_number
,           database_name
,           schema_name
,           table_name
,           avg_fragmentation_in_percent
,           forwarded_record_count
,           page_count
FROM        #HeapIssues
ORDER BY    database_name
,           forwarded_record_count DESC;

-- Code review patterns
SELECT      'Query No 3e' AS check_number
,           database_name
,           schema_name
,           object_name
,           type_desc
,           matched_pattern
FROM        #ModulePatterns
ORDER BY    database_name
,           schema_name
,           object_name
,           matched_pattern;

-- Top Query Store queries
SELECT      'Query No 3f' AS check_number
,           database_name
,           query_id
,           plan_id
,           executions
,           avg_duration_ms
,           avg_cpu_ms
,           avg_logical_reads
,           last_execution_time
,           query_sql_text
FROM        #TopQueryStoreQueries
ORDER BY    database_name
,           avg_duration_ms DESC;

/*-------------------------------------------------------------------------------
4) Deprecated features at server level

What are we querying?
  Deprecated feature usage counters recorded by SQL Server.

Why it matters:
  Shows whether old syntax, objects, datatypes, or behaviours are still being
  used anywhere on the instance.

Red flags:
  - Non-zero counters for deprecated objects or datatypes
  - High or rising counts for core compatibility views
  - Deprecated LOB datatypes such as text/ntext/image still in use
-------------------------------------------------------------------------------*/
SELECT      'Query No 4' AS check_number
,           object_name
,           counter_name
,           instance_name
,           cntr_value
FROM        sys.dm_os_performance_counters
WHERE       object_name LIKE '%Deprecated Features%'
AND         cntr_value  > 0
ORDER BY    cntr_value DESC
,           counter_name
,           instance_name;