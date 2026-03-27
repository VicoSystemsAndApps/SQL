-- Red flag: Blocking, excessive elapsed times.

-- Top 10 longest currently running requests
SELECT		r.session_id
,			r.start_time
,			r.status
,			r.command
,			r.cpu_time
,			r.total_elapsed_time
,			t.text					AS QueryText
FROM		sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE		r.session_id > 50
ORDER BY	r.total_elapsed_time DESC;