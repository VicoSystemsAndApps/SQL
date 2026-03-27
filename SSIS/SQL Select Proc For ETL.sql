/***************************************************************
			
Created By:		Raymond F. Betts
Created Date:	7th August 2017
Description:	Dynamically creates text for procedure for ETL
				Change Tracking Processses		
'****************************************************************/
DECLARE @SchemaName	VARCHAR(200)	= 'EDA_TENANT1'
,		@TableName	VARCHAR(200)	= 'ADDRESS'
,		@SQL		VARCHAR(MAX)	= ''
,		@PrimaryKey	VARCHAR(200)	= '';

-- Get Primary Key field
SELECT	@PrimaryKey = ccu.COLUMN_NAME
FROM	INFORMATION_SCHEMA.TABLE_CONSTRAINTS		tc
JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE	ccu ON tc.CONSTRAINT_NAME = ccu.Constraint_name
WHERE	tc.CONSTRAINT_TYPE	= 'Primary Key'
AND		tc.TABLE_SCHEMA		= @SchemaName
AND		tc.TABLE_NAME		= @TableName;


-- Create Proc Text
SET @SQL =	'CREATE PROCEDURE etl.' + @SchemaName + '_' + @TableName + '_ByCTID' + CHAR(13) +
'
/***************************************************************
			
Created By:		Raymond F. Betts
Created Date:	' + CONVERT(VARCHAR, CONVERT(DATE, GETDATE())) + CHAR(13) +
'Description:	Select From ' + @SchemaName + '.' + @TableName + CHAR(13) +
'****************************************************************/
( 
	@LastChangeTrackingID		INT = -1
,	@CurrentChangeTrackingID	INT = -1 
)
AS

BEGIN TRY

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SELECT ';

SELECT DISTINCT @SQL  = @SQL +  SUBSTRING(
										(SELECT ', a.' +  c.name + CHAR(10)
										FROM	sys.tables	t
										JOIN	sys.schemas	s ON s.schema_id = t.schema_id
										JOIN	sys.columns	c ON c.object_id = t.object_id
										WHERE	t.name = @TableName
										AND		s.name = @SchemaName	
										ORDER BY c.column_id
										FOR XML PATH (''))
										, 2, 8000) 

SET @SQL = @SQL  
			+ ', ISNULL(b.SYS_CHANGE_VERSION, -1) AS SYS_CHANGE_VERSION' + CHAR(13)
			+ ', ISNULL(b.SYS_CHANGE_OPERATION, ''I'') AS SYS_CHANGE_OPERATION' + CHAR(13)
			+ 'FROM ' + @SchemaName + '.' + @TableName + ' a ' + CHAR(13)
			+ 'LEFT JOIN CHANGETABLE(CHANGES ' + @SchemaName + '.' + @TableName + ', @LastChangeTRackingID) b ON a.' + @PrimaryKey + ' = b.' + @PrimaryKey
			+ CHAR(13) +
			+ 'WHERE ISNULL(b.SYS_CHANGE_VERSION, -1) <= @CurrentChangeTrackingID;' + CHAR(13) + CHAR(13) 
			+ 'END TRY' + CHAR(13) + CHAR(13) 
			+ 'BEGIN CATCH' + CHAR(13)
			+ '	THROW;' + CHAR(13)
			+ 'END CATCH'

PRINT @SQL



