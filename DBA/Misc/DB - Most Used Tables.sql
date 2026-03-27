SELECT      OBJECT_SCHEMA_NAME(i.object_id)                                                     AS schema_name
,           OBJECT_NAME(i.object_id)                                                            AS table_name
,           FORMAT(SUM(s.user_seeks + s.user_scans + s.user_lookups), 'N0')                     AS total_reads
,           FORMAT(SUM(s.user_updates), 'N0')                                                   AS total_writes
,           FORMAT(SUM(s.user_seeks + s.user_scans + s.user_lookups + s.user_updates), 'N0')    AS total_activity
FROM        sys.dm_db_index_usage_stats s
JOIN        sys.indexes                 i	ON	s.object_id = i.object_id
											AND s.index_id	= i.index_id
WHERE		s.database_id	= DB_ID()
AND			i.object_id		> 100 -- exclude system tables
GROUP BY	i.object_id
ORDER BY	SUM(s.user_seeks + s.user_scans + s.user_lookups + s.user_updates) DESC;
