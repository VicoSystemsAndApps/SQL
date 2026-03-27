-- Who's connected / recently active, grouped by DB
SELECT      DB_NAME(s.database_id)          AS database_name
,           COUNT(1)                        AS session_count
,           MIN(s.last_request_start_time)  AS first_request_start
,           MAX(s.last_request_end_time)    AS last_request_end
FROM        sys.dm_exec_sessions    s
JOIN        sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE       s.is_user_process = 1
GROUP BY    DB_NAME(s.database_id)
ORDER BY    last_request_end DESC;

-- Shows last user seeks/scans/lookups/updates in each DB
WITH usage AS 
(
SELECT		DB_NAME(database_id)	AS database_name
,			MAX(last_user_seek)		AS last_seek
,			MAX(last_user_scan)		AS last_scan
,			MAX(last_user_lookup)	AS last_lookup
,			MAX(last_user_update)	AS last_update
FROM		sys.dm_db_index_usage_stats
WHERE		database_id > 4
GROUP BY	DB_NAME(database_id)
)
SELECT		*
FROM		usage
ORDER BY	COALESCE(last_seek, last_scan, last_lookup, last_update) DESC;

-- Snapshot-style counters per file; take a note of values now
SELECT		DB_NAME(vfs.database_id)				AS database_name
,			mf.name									AS logical_name
,			mf.type_desc
,			vfs.file_id
,			FORMAT(vfs.num_of_reads, 'N0')			AS num_of_reads
,			FORMAT(vfs.num_of_writes, 'N0')			AS num_of_writes
,			FORMAT(vfs.num_of_bytes_read, 'N0')		AS bytes_read
,			FORMAT(vfs.num_of_bytes_written, 'N0')	AS bytes_written
,			FORMAT(vfs.sample_ms, 'N0')				AS sample_ms
,			FORMAT(vfs.size_on_disk_bytes,'N0')		AS size_on_disk_bytes
FROM		sys.dm_io_virtual_file_stats(NULL, NULL)	vfs
JOIN		sys.master_files							mf	ON	vfs.database_id = mf.database_id 
															AND vfs.file_id		= mf.file_id
ORDER BY	database_name
,			file_id;



