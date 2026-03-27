/*
Run on the primary or secondary (AG)

Red Flags to Watch
	- State/Health: not SYNCHRONIZED / not HEALTHY
	- Redo Queue: growing, >100 MB for long periods
	- Log Send Queue: growing, >100 MB
	- Redo Rate: near zero while redo queue > 0
	- Commit Lag: consistently >5–10s (sync), >30–60s (async)

*/

SELECT		r.replica_server_name
,			DB_NAME(db.database_id)                                         AS DatabaseName
,			drs.is_primary_replica
,			drs.synchronization_state_desc
,			drs.synchronization_health_desc
,			drs.log_send_queue_size / 1024.0                                AS log_send_queue_mb
,			drs.redo_queue_size / 1024.0                                    AS redo_queue_mb
,			drs.redo_rate / 1024.0                                          AS redo_rate_mb_per_sec
,			drs.log_send_rate / 1024.0                                      AS log_send_rate_mb_per_sec
,			DATEDIFF(SECOND, drs.last_commit_time, GETUTCDATE())            AS commit_lag_seconds
,			CASE    WHEN drs.synchronization_health_desc != 'HEALTHY' 
                    OR drs.synchronization_state_desc != 'SYNCHRONIZED'
                        THEN 'CRITICAL'
                    WHEN drs.redo_queue_size/1024.0 > 100 
                    OR drs.log_send_queue_size/1024.0 > 100
                        THEN 'WARNING'
                    WHEN drs.redo_queue_size > 0 AND drs.redo_rate = 0
                        THEN 'WARNING'
                    ELSE 'OK'
            END                                                             AS ReplicaStatus
FROM		sys.dm_hadr_database_replica_states drs
JOIN		sys.databases                       db  ON drs.database_id	= db.database_id
JOIN		sys.availability_replicas           r	ON drs.replica_id	= r.replica_id
ORDER BY	db.database_id
,           redo_queue_mb DESC
,			log_send_queue_mb DESC;
