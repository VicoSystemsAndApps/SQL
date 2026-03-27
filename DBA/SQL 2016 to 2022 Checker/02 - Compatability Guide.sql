/*------------------------------------------------------------------------------
UPGRADE RISK AUDIT: SQL Server 2016 -> 2022

Purpose:
  Find settings, code patterns, and optimizer controls that are likely to
  affect query behaviour after upgrade or after raising compatibility level.

Scope:
  - All ONLINE user databases
  - Read-only checks

Main areas:
  1. Server-level parallelism settings
  2. Database compatibility levels
  3. Query Store readiness
  4. Database scoped optimiser settings
  5. Deprecated feature usage
  6. Plan guides
  7. Query/module patterns that may force plans or indicate stale code

Notes:
  - Upgrade engine first, change compatibility level later
  - Query Store should ideally be enabled before the upgrade
  - These checks are about upgrade risk, not general maintenance
------------------------------------------------------------------------------*/

USE master;

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#DbList') IS NOT NULL DROP TABLE #DbList;
CREATE TABLE #DbList
(
    dbname sysname NOT NULL PRIMARY KEY
);

INSERT  #DbList 
        (dbname)
SELECT  name
FROM    sys.databases
WHERE   database_id         > 4
AND     state_desc          = 'ONLINE'
AND     source_database_id  IS NULL;

/*--------------------------------------------------------------------------------
0. SERVER SUMMARY

What are we querying?
  Basic engine/version summary so you know where the audit was run.

Red flags:
  - Not actually on the expected source instance
  - Unexpected edition / version / HA configuration
--------------------------------------------------------------------------------*/
SELECT  
       'Query No 0'                            AS check_number
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

/*--------------------------------------------------------------------------------
1. SERVER-LEVEL PARALLELISM SETTINGS

What are we querying?
  Server-wide MAXDOP and cost threshold for parallelism.

Why it matters:
  These directly affect parallel plan choice and can change query behaviour.

Red flags:
  - MAXDOP = 0 on busy OLTP without deliberate reason
  - Very low cost threshold for parallelism
  - Settings that nobody can explain
--------------------------------------------------------------------------------*/
SELECT      'Query No 1'  AS check_number
,           name
,           value
,           value_in_use
,           description
FROM        sys.configurations
WHERE       name IN ('max degree of parallelism', 'cost threshold for parallelism')
ORDER BY    name;

/*--------------------------------------------------------------------------------
2. GLOBAL TRACE FLAGS

What are we querying?
  Startup/global trace flags that may alter optimizer or runtime behaviour.

Why it matters:
  Old estates often contain forgotten trace flags added as workarounds.

Red flags:
  - Trace flags no one recognises
  - Optimizer-related flags left behind from old incidents
  - Anything acting as a hidden workaround for CE/plan issues
--------------------------------------------------------------------------------*/
DBCC TRACESTATUS(-1);

/*--------------------------------------------------------------------------------
3. DATABASE COMPATIBILITY LEVELS

What are we querying?
  Current compatibility level for every user database.

Why it matters:
  Engine upgrade and optimiser behaviour change are separate steps.

Red flags:
  - Unexpected mix of compatibility levels
  - Databases still on old levels with no plan
  - Assumption that engine upgrade alone gives 2022 optimiser behaviour
--------------------------------------------------------------------------------*/
SELECT      'Query No 2'                    AS check_number
,           d.name                          AS DBName
,           d.compatibility_level
,           d.recovery_model_desc
,           d.containment_desc
,           d.state_desc
FROM        sys.databases d
WHERE       d.database_id > 4
ORDER BY    d.name;

--------------------------------------------------------------------------------
-- Temp tables for database-level findings
--------------------------------------------------------------------------------
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

IF OBJECT_ID('tempdb..#PlanGuides') IS NOT NULL DROP TABLE #PlanGuides;
CREATE TABLE #PlanGuides
(
    database_name   SYSNAME
,   plan_guide_name SYSNAME NULL
,   scope_type_desc NVARCHAR(60) NULL
,   is_disabled     BIT NULL
,   query_text      NVARCHAR(MAX) NULL
,   hints           NVARCHAR(MAX) NULL
);

IF OBJECT_ID('tempdb..#ModuleFindings') IS NOT NULL DROP TABLE #ModuleFindings;
CREATE TABLE #ModuleFindings
(
    database_name   SYSNAME
,   schema_name     SYSNAME NULL
,   object_name     SYSNAME NULL
,   object_type     NVARCHAR(60) NULL
,   finding         NVARCHAR(100) NULL
);

DECLARE @db     SYSNAME
,       @sql    NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT      dbname
FROM        #DbList
ORDER BY    dbname;

OPEN cur;
FETCH NEXT FROM cur INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN

    /*--------------------------------------------------------------------------------
    4. QUERY STORE STATUS PER DATABASE
    
    What are we querying?
      Whether Query Store is enabled, writable, and sized sensibly.
    
    Why it matters:
      Query Store is the main tool for baseline, regression detection,
      plan forcing, and several 2022 tuning features.
    
    Red flags:
      - Query Store OFF
      - Query Store READ_ONLY unexpectedly
      - Very small max size
      - Wait stats capture off where you expected it on
    --------------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT #QueryStoreStatus
    (   database_name
    ,   actual_state_desc
    ,   desired_state_desc
    ,   readonly_reason
    ,   current_storage_size_mb
    ,   max_storage_size_mb
    ,   query_capture_mode_desc
    ,   wait_stats_capture_mode_desc
    )
    SELECT  DB_NAME()
    ,       actual_state_desc
    ,       desired_state_desc
    ,       readonly_reason
    ,       current_storage_size_mb
    ,       max_storage_size_mb
    ,       query_capture_mode_desc
    ,       wait_stats_capture_mode_desc
    FROM    sys.database_query_store_options;
    ';
    EXEC sys.sp_executesql @sql;

    /*--------------------------------------------------------------------------------
    5. DATABASE-SCOPED OPTIMIZER SETTINGS
    
    What are we querying?
      Database-scoped settings that can override or shape optimizer behaviour.
    
    Why it matters:
      These settings can preserve old behaviour or disable useful modern behaviour.
    
    Red flags:
      - LEGACY_CARDINALITY_ESTIMATION = ON
      - PARAMETER_SNIFFING = OFF
      - MAXDOP overridden at database level without clear reason
      - QUERY_OPTIMIZER_HOTFIXES changed from default with no explanation
      - 2022 features disabled when testing compat 160
    --------------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT #DbScopedConfigs
    (   database_name
    ,   config_name
    ,   value
    ,   value_for_secondary
    ,   is_value_default
    )
    SELECT  DB_NAME()
    ,       name
    ,       value
    ,       value_for_secondary
    ,       is_value_default
    FROM    sys.database_scoped_configurations
    WHERE   name IN
    (
        ''MAXDOP''
    ,   ''LEGACY_CARDINALITY_ESTIMATION''
    ,   ''QUERY_OPTIMIZER_HOTFIXES''
    ,   ''PARAMETER_SNIFFING''
    ,   ''PARAMETER_SENSITIVE_PLAN_OPTIMIZATION''
    ,   ''DOP_FEEDBACK''
    );
    ';
    EXEC sys.sp_executesql @sql;

    /*--------------------------------------------------------------------------------
    6. PLAN GUIDES
    
    What are we querying?
      Plan guides that can inject hints or force plan behaviour without
      changing the source code.
    
    Why it matters:
      They are easy to forget and can make upgrade behaviour confusing.
    
    Red flags:
      - Any plan guide nobody knows about
      - Forced hints left behind from historic incidents
      - Plan guides used instead of proper query fixes
    --------------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT #PlanGuides
    (   database_name
    ,   plan_guide_name
    ,   scope_type_desc
    ,   is_disabled
    ,   query_text
    ,   hints
    )
    SELECT  DB_NAME()
    ,       name
    ,       scope_type_desc
    ,       is_disabled
    ,       query_text
    ,       hints
    FROM sys.plan_guides;
    ';
    EXEC sys.sp_executesql @sql;

    /*--------------------------------------------------------------------------------
    7. MODULE SEARCH: HARD-CODED PARALLELISM / OPTIMIZER FORCING
    
    What are we querying?
      Stored procedures, functions, views, and triggers containing hints or
      directives that can strongly affect plan choice.
    
    Why it matters:
      These are often old workarounds that suppress modern optimizer behaviour.
    
    Red flags:
      - OPTION (MAXDOP ...)
      - QUERYTRACEON
      - FORCE ORDER
      - USE PLAN
      - HASH / LOOP / MERGE JOIN hints
      - FORCESEEK / FORCESCAN
    --------------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT  #ModuleFindings 
            (database_name, schema_name, object_name, object_type, finding)
    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''MAXDOP hint''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%MAXDOP%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''QUERYTRACEON''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%QUERYTRACEON%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''FORCE ORDER''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%FORCE ORDER%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''USE PLAN''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%USE PLAN%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''FORCESEEK / FORCESCAN''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%FORCESEEK%''
    OR      sm.definition LIKE ''%FORCESCAN%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''Explicit JOIN hint''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%LOOP JOIN%''
    OR      sm.definition LIKE ''%HASH JOIN%''
    OR      sm.definition LIKE ''%MERGE JOIN%'';
    ';
    EXEC sys.sp_executesql @sql;

    /*--------------------------------------------------------------------------------
    8. MODULE SEARCH: STALE OR RISKY CODE PATTERNS
    
    What are we querying?
      Common code patterns that may indicate older coding style, workaround-led
      design, or query behaviour that deserves review.
    
    Why it matters:
      These do not always mean "bad", but they are good candidates for review
      before or after moving to 2022.
    
    Red flags:
      - Heavy NOLOCK usage
      - Routine RECOMPILE hints
      - CURSOR-heavy logic
      - FOR XML PATH string concatenation still everywhere
      - sp_xml_preparedocument usage
      - RAISERROR in older procedural code
    --------------------------------------------------------------------------------*/
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT  #ModuleFindings (database_name, schema_name, object_name, object_type, finding)
    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''NOLOCK''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%WITH (NOLOCK)%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''OPTION (RECOMPILE)''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%OPTION (RECOMPILE)%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''CURSOR''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%CURSOR%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''FOR XML PATH string concat''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%FOR XML PATH(%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''sp_xml_preparedocument''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%sp_xml_preparedocument%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''RAISERROR''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%RAISERROR%''

    UNION ALL

    SELECT  DB_NAME(), OBJECT_SCHEMA_NAME(sm.object_id), OBJECT_NAME(sm.object_id), o.type_desc, ''Dynamic SQL''
    FROM    sys.sql_modules sm
    JOIN    sys.objects     o ON sm.object_id = o.object_id
    WHERE   sm.definition LIKE ''%sp_executesql%''
    OR      sm.definition LIKE ''%EXEC(%''
    OR      sm.definition LIKE ''%EXECUTE(%'';
    ';
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM cur INTO @db;
END

CLOSE cur;
DEALLOCATE cur;

/*--------------------------------------------------------------------------------
9. DEPRECATED FEATURE USAGE

What are we querying?
  Deprecated feature counters exposed by SQL Server.

Why it matters:
  This is hard evidence that old features are still being used somewhere.

Red flags:
  - Non-zero counters for deprecated functionality
  - Counters increasing over time
  - Features you were not aware were still in use
--------------------------------------------------------------------------------*/
SELECT      'Query No 9'                    AS check_number
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

/*--------------------------------------------------------------------------------
10. RESULTS: QUERY STORE STATUS

Red flags to watch:
  - OFF
  - READ_ONLY unexpectedly
  - Small storage cap
--------------------------------------------------------------------------------*/
SELECT      'Query No 10'                    AS check_number
,           database_name
,           actual_state_desc
,           desired_state_desc
,           readonly_reason
,           current_storage_size_mb
,           max_storage_size_mb
,           query_capture_mode_desc
,           wait_stats_capture_mode_desc
FROM        #QueryStoreStatus
ORDER BY    database_name;

/*--------------------------------------------------------------------------------
11. RESULTS: DATABASE-SCOPED OPTIMIZER SETTINGS

Red flags to watch:
  - LEGACY_CARDINALITY_ESTIMATION = 1
  - PARAMETER_SNIFFING = 0
  - MAXDOP not default without good reason
  - QUERY_OPTIMIZER_HOTFIXES changed from default
--------------------------------------------------------------------------------*/
SELECT      'Query No 11'                    AS check_number
,           database_name
,           config_name
,           value
,           value_for_secondary
,           is_value_default
FROM        #DbScopedConfigs
ORDER BY    database_name
,           config_name;

/*--------------------------------------------------------------------------------
12. RESULTS: PLAN GUIDES

Red flags to watch:
  - Any active plan guide with no current owner/explanation
  - Old forced hints left behind
--------------------------------------------------------------------------------*/
SELECT      'Query No 12'                    AS check_number
,           database_name
,           plan_guide_name
,           scope_type_desc
,           is_disabled
,           query_text
,           hints
FROM        #PlanGuides
ORDER BY    database_name
,           plan_guide_name;

/*--------------------------------------------------------------------------------
13. RESULTS: MODULE FINDINGS

Red flags to watch:
  - Repeated forcing hints across many procedures
  - Heavy NOLOCK / RECOMPILE / CURSOR usage
  - Query-level MAXDOP or QUERYTRACEON
  - Old XML/string concat patterns spread widely
--------------------------------------------------------------------------------*/
SELECT      'Query No 13'                    AS check_number
,           database_name
,           schema_name
,           object_name
,           object_type
,           finding
FROM        #ModuleFindings
ORDER BY    database_name
,           schema_name
,           object_name
,           finding;
