DECLARE @TableNameFull  NVARCHAR(1000)  = '[DocumotiveRS_V4].[dbo].[DimLocation]'
,       @TableName      NVARCHAR(500)   = 'DocumotiveRS_V4';

-- Un-used / low value indexes
-- Candidates to drop: few reads, many writes
SELECT      DB_NAME(s.database_id) AS db, OBJECT_NAME(s.[object_id], s.database_id) AS table_name
,           i.name
,           s.user_seeks + s.user_scans + s.user_lookups                            AS reads
,           s.user_updates                                                          AS writes
FROM        sys.dm_db_index_usage_stats s
JOIN        sys.indexes                 i   ON  i.[object_id]   = s.[object_id] 
                                            AND i.index_id      = s.index_id
WHERE       s.database_id = DB_ID(@TableName)
AND         s.[object_id] = OBJECT_ID(@TableNameFull)
ORDER BY    reads
,           writes DESC;

-- Key + include definitions to spot overlaps
SELECT      i.name
,           i.index_id
,           i.type_desc
,           i.is_unique
,           STUFF(( SELECT      ',' + COL_NAME(ic.[object_id], ic.column_id)
                    FROM        sys.index_columns ic
                    WHERE       ic.[object_id]          = i.[object_id] 
                    AND         ic.index_id             = i.index_id 
                    AND         ic.is_included_column   = 0
                    ORDER BY    ic.key_ordinal
                    FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS key_cols
,           STUFF(( SELECT      ',' + COL_NAME(ic.[object_id], ic.column_id)
                    FROM        sys.index_columns ic
                    WHERE       ic.[object_id]          = i.[object_id] 
                    AND         ic.index_id             = i.index_id 
                    AND         ic.is_included_column   = 1
                    ORDER BY    ic.index_column_id
                    FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS include_cols
FROM        sys.indexes i
WHERE       i.[object_id] = OBJECT_ID(@TableNameFull)
ORDER BY    i.name;

