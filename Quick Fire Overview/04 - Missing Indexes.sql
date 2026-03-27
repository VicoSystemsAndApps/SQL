-- Red flag: Very high "ImprovementMeasure" values.

SELECT		DB_NAME(mid.database_id)																		AS DatabaseName
,			migs.avg_total_user_cost * (migs.avg_user_impact * 0.01) * (migs.user_seeks + migs.user_scans)  AS ImprovementMeasure
,			mid.statement                                                                                   AS TableName
,			mid.equality_columns
,			mid.inequality_columns
,			mid.included_columns
,			migs.user_seeks
,			migs.user_scans
FROM		sys.dm_db_missing_index_group_stats		migs
JOIN		sys.dm_db_missing_index_groups			mig ON migs.group_handle = mig.index_group_handle
JOIN		sys.dm_db_missing_index_details			mid ON mig.index_handle = mid.index_handle
WHERE		mid.database_id > 4                  -- exclude system DBs
ORDER BY	ImprovementMeasure DESC;