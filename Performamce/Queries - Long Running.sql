/*
- Sort by Avg Worker Time → top CPU burners.
- Sort by Avg Logical Reads → likely index/design fixes.
- Sort by Avg Elapsed → long runners; check if elapsed >> worker (waits).
- Scan flags (Spill Warn / Implicit Conv / Key Lookups / UDFs) and open the plan for the worst offenders.
- Look at Max vs Min elapsed for variance → parameter sniffing candidates.
- Check Creation Time for “new & hot” patterns.

- Execution Count:			how many times the query has run since plan compiled; high counts = “death by a thousand cuts.”
- Total Logical Reads (MB):	total data read from cache; very high totals = IO pressure from frequent queries.
- Avg Logical Reads (MB):	average data read per execution; high averages = scans, missing indexes, or wide rows.
- Total Worker Time (ms):	total CPU consumed; high totals = cumulative CPU hogs.
- Avg Worker Time (ms):		average CPU per run; high averages = CPU-bound query, check for UDFs, scalar ops, bad joins.
- Total Elapsed Time (ms):	total wall-clock run time; high totals = overall workload impact.
- Avg Elapsed Time (ms):	average run time; if much greater than Avg Worker Time → wait issues (IO, blocking, memory).

- Spill To Temp DB:			Query spilled to tempdb (possible memory grant issue)
- Impicit Conversions:		May prevent index usage
- Impicit Conversions Alt:	Scalar operator
- Key Lookups: Potential	missing covering index
- UDF Is In Plan:			Row-by-row overhead due to UDF
*/


SELECT TOP(50)	DB_NAME(t.dbid)																							AS [DB]
,				qs.execution_count																						AS [Execution Count]
,				(qs.total_logical_reads)*8/1024.0																		AS [Total Logical Reads (MB)]
,				(qs.total_logical_reads/qs.execution_count)*8/1024.0													AS [Avg Logical Reads (MB)]
,				(qs.total_worker_time)/1000.0																			AS [Total Worker Time (ms)]
,				(qs.total_worker_time/qs.execution_count)/1000.0														AS [Avg Worker Time (ms)]
,				(qs.total_elapsed_time)/1000.0																			AS [Total Elapsed Time (ms)]
,				(qs.total_elapsed_time/qs.execution_count)/1000.0														AS [Avg Elapsed Time (ms)]
,				qs.creation_time																						AS [Creation Time]
,				TRY_CAST(qp.query_plan AS XML).exist('//Warnings[@SpillToTempDb="1"]')									AS SpillToTempDb
,				TRY_CAST(qp.query_plan AS XML).exist('//Convert[@Implicit="1"]')										AS ImplicitConversions
,				TRY_CAST(qp.query_plan AS XML).exist('//ScalarOperator[contains(@ScalarString,"CONVERT_IMPLICIT")]')	AS ImplicitConversionsAlt
,				TRY_CAST(qp.query_plan AS XML).exist('//RelOp[@PhysicalOp="Key Lookup"]')								AS KeyLookups
,				TRY_CAST(qp.query_plan AS XML).exist('//UserDefinedFunction')											AS UDFsInPlan
,				t.text																									AS [Complete Query Text]
,				qp.query_plan																							AS [Query Plan]
FROM			sys.dm_exec_query_stats					qs WITH (NOLOCK)
CROSS APPLY		sys.dm_exec_sql_text(plan_handle)		t
CROSS APPLY		sys.dm_exec_query_plan(plan_handle)		qp
WHERE			t.dbid = DB_ID()
ORDER BY 	
--				qs.execution_count DESC				-- frequently ran query
--				[Total Logical Reads (MB)] DESC		-- High Disk Reading query
--				[Avg Worker Time (ms)] DESC			-- High CPU query
				[Avg Elapsed Time (ms)] DESC		-- Long Running query
OPTION (RECOMPILE);