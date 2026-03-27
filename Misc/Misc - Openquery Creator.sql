

declare @svr nvarchar(500) = 'pfglbissis01'
,		@sql nvarchar(max);

SET @sql = 'SELECT *
FROM OPENQUERY(' + @svr + '		
				,	''select    cast(e.start_time as date) as runDate
					,         e.folder_name
					,         e.project_name
					,         e.package_name
					,         e.execution_id
					,         e.start_time as runDateTime
					,         case when om.message_type =  90 then ''''Diagnostic''''
									when om.message_type = 110 then ''''Warning''''
									when om.message_type = 120 then ''''Error''''
									when om.message_type = 130 then ''''Task Failed''''
								end as message_type_description
					,         om.operation_message_id
					,         om.message_time
					from      SSISDB.catalog.executions e with (nolock)
					join      SSISDB.catalog.operations o with (nolock)
					on        e.execution_id = o.operation_id
					join      SSISDB.catalog.operation_messages om with (nolock)
					on        o.operation_id            =  om.operation_id
					where     om.message_type           in (90, 110, 120, 130)
					and       om.operation_message_id   >  95476189'' 
				);'

print @sql;

SELECT *
FROM OPENQUERY(pfglbissis01		
				,	'select    cast(e.start_time as date) as runDate
					,         e.folder_name
					,         e.project_name
					,         e.package_name
					,         e.execution_id
					,         e.start_time as runDateTime
					,         case when om.message_type =  90 then ''Diagnostic''
									when om.message_type = 110 then ''Warning''
									when om.message_type = 120 then ''Error''
									when om.message_type = 130 then ''Task Failed''
								end as message_type_description
					,         om.operation_message_id
					,         om.message_time
					from      SSISDB.catalog.executions e with (nolock)
					join      SSISDB.catalog.operations o with (nolock)
					on        e.execution_id = o.operation_id
					join      SSISDB.catalog.operation_messages om with (nolock)
					on        o.operation_id            =  om.operation_id
					where     om.message_type           in (90, 110, 120, 130)
					and       om.operation_message_id   >  95476189' 
				);
