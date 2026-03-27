-- Red flag: Frequent autogrowths on busy databases.

-- Requires default trace (on by default unless disabled)
SELECT      te.name AS EventName
,           t.DatabaseName
,           t.FileName
,           (t.IntegerData * 8 / 1024) AS GrowthMB
,           t.StartTime
FROM        sys.fn_trace_gettable(CONVERT(VARCHAR(150), (
                                                        SELECT TOP 1    f.[value] 
                                                        FROM            sys.fn_trace_getinfo(NULL) f 
                                                        WHERE           f.property = 2
                                                        )), DEFAULT)    t
JOIN        sys.trace_events                                            te ON t.EventClass = te.trace_event_id
WHERE       te.name = 'Data File Auto Grow' 
OR          te.name = 'Log File Auto Grow'
ORDER BY    t.StartTime DESC;
