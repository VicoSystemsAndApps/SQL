-- Runnable tasks & signal waits (instantaneous CPU pressure clues)
SELECT	GETDATE() AS SampleTime
,		runnable_tasks_count
,		work_queue_count
,		pending_disk_io_count
FROM	sys.dm_os_schedulers
WHERE	scheduler_id < 255;  -- visible online schedulers

-- Top waits (last reset) focused on CPU symptoms
SELECT TOP 10	wait_type
,				waiting_tasks_count
,				wait_time_ms
,				signal_wait_time_ms
FROM			sys.dm_os_wait_stats
WHERE			wait_type NOT LIKE 'SLEEP%' 
AND				wait_type NOT IN ('BROKER_TASK_STOP','BROKER_TO_FLUSH')
ORDER BY		wait_time_ms DESC;
