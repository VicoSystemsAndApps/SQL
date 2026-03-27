SELECT      DB_NAME()                                                                       AS DatabaseName
,           s.name                                                                          AS SchemaName
,           t.name                                                                          AS TableName
,           t.is_ms_shipped                                                                 AS MicrosoftTable
,           FORMAT(SUM(IIF(ps.index_id IN (0,1), ps.row_count, 0)), '##,##0')               AS [RowCount]
,           FORMAT(SUM(ps.used_page_count) / 128.0, 'N2')                                   AS Used_MB
,           FORMAT((SUM(ps.reserved_page_count) - SUM(ps.used_page_count)) / 128.0, 'N2')   AS Unused_MB
,           FORMAT(SUM(ps.reserved_page_count) / 128.0, 'N2')                               AS Total_MB
FROM        sys.dm_db_partition_stats   ps
JOIN        sys.tables                  t   ON ps.object_id = t.object_id
JOIN        sys.schemas                 s   ON t.schema_id  = s.schema_id
WHERE       t.name      NOT LIKE 'dt%'
AND         t.object_id > 255
GROUP BY    s.name
,           t.name
,           t.is_ms_shipped
ORDER BY    SUM(ps.used_page_count) / 128.0 DESC
,           s.name
,			t.name;
