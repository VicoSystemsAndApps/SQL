/*
Are long transactions holding locks?
Open transactions and how long they’ve been open
*/

SELECT		s.session_id
,			s.login_name
,			s.host_name
,			s.program_name
,			r.status
,			r.command
,			r.cpu_time
,			r.total_elapsed_time/1000.0													AS elapsed_s
,			at.transaction_id, DATEDIFF(SECOND, at.transaction_begin_time, GETDATE())	AS tran_seconds
,			r.wait_type
,			r.wait_time
,			r.blocking_session_id
,			r.wait_resource
FROM		sys.dm_tran_session_transactions	st
JOIN		sys.dm_tran_active_transactions		at	ON st.transaction_id	= at.transaction_id
JOIN		sys.dm_exec_sessions				s	ON s.session_id			= st.session_id
LEFT JOIN	sys.dm_exec_requests				r	ON r.session_id			= s.session_id
ORDER BY	tran_seconds DESC;

/*
Who’s holding locks right now (even if no blocking yet)?
Shows holders and waiters and the exact lock resource.
*/

SELECT		tl.resource_type
,			tl.resource_database_id
,			DB_NAME(tl.resource_database_id)	AS db_name
,			tl.resource_associated_entity_id	AS hobt_or_obj
,			tl.request_mode
,			tl.request_status
,			tl.request_session_id
,			wt.blocking_session_id
,			wt.wait_duration_ms
,			wt.wait_type
,			wt.resource_description
FROM		sys.dm_tran_locks		tl
LEFT JOIN	sys.dm_os_waiting_tasks wt	ON wt.resource_address = tl.lock_owner_address
ORDER BY	wt.wait_duration_ms DESC;

/*
Any hot objects / escalations?
Find objects that see lots of locks/escalations (run per DB)
*/
SELECT		OBJECT_NAME(ios.object_id) AS obj_name
,			ios.index_id
,			ios.row_lock_count
,			ios.page_lock_count
,			ios.page_lock_wait_count
,			ios.page_lock_wait_in_ms
,			ios.row_lock_wait_count
,			ios.row_lock_wait_in_ms
,			ios.index_lock_promotion_attempt_count
,			ios.index_lock_promotion_count
FROM		sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) ios
ORDER BY	ios.row_lock_wait_in_ms + ios.page_lock_wait_in_ms DESC;


