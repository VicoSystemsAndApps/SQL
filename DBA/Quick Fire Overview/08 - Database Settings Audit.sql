-- Red flag: AUTO_CLOSE = ON, AUTO_SHRINK = ON, wrong recovery model.

-- Check recovery models, auto-shrink, auto-close etc.
SELECT  name
,       recovery_model_desc
,       user_access_desc
,       is_auto_shrink_on
,       is_auto_close_on
,       is_auto_create_stats_on
,		is_auto_update_stats_on
FROM	sys.databases;