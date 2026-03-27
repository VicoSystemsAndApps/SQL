-- How much memory SQL Server is using right now
SELECT  physical_memory_in_use_kb / 1024		AS MemoryUsed_MB
,       locked_page_allocations_kb / 1024		AS LockedPages_MB
,       page_fault_count
,       memory_utilization_percentage
,		available_commit_limit_kb / 1024		AS AvailableCommitLimit_MB
FROM	sys.dm_os_process_memory;

-- Shows which DBs consume the most memory in the buffer pool.
SELECT		COUNT(*) * 8 / 1024			AS BufferPool_MB
,			DB_NAME(bd.database_id)		AS DatabaseName
FROM		sys.dm_os_buffer_descriptors	bd
WHERE		database_id > 4
GROUP BY	DB_NAME(bd.database_id)
--ORDER BY	BufferPool_MB DESC;
ORDER BY	DB_NAME(bd.database_id);

-- Active queries asking for memory
-- If you see queries stuck waiting on memory grants → memory pressure.
SELECT		session_id
,			request_id
,			requested_memory_kb
,			granted_memory_kb
,			required_memory_kb
,			used_memory_kb
,			max_used_memory_kb
,			wait_time_ms
,			query_cost
,			dop
,			grant_time
FROM		sys.dm_exec_query_memory_grants
ORDER BY	requested_memory_kb DESC;