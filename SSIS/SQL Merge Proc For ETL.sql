/***************************************************************
			
Created By:		Raymond F. Betts
Created Date:	7th August 2017
Description:	Dynamically creates text for procedure for ETL
				Change Tracking Processses		
'****************************************************************/
DECLARE @SourceSchemaName	VARCHAR(200)	= 'Landing'
,		@SourceTableName	VARCHAR(200)	= 'APPLICANT'
,		@DestSchemaName		VARCHAR(200)	= 'Consolidated'
,		@DestTableName		VARCHAR(200)	= 'APPLICANT'
,		@SQL				VARCHAR(MAX)	= ''
,		@SQL2				VARCHAR(MAX)	= ''
,		@SQL3				VARCHAR(MAX)	= ''
,		@PrimaryKey			VARCHAR(200)	= ''
,		@IsIdentity			BIT				= 0
,		@XML				VARCHAR(MAX)	= '';

-- Get Primary Key field
SELECT	@PrimaryKey = ccu.COLUMN_NAME
FROM	INFORMATION_SCHEMA.TABLE_CONSTRAINTS		tc
JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE	ccu ON tc.CONSTRAINT_NAME = ccu.Constraint_name
WHERE	tc.CONSTRAINT_TYPE	= 'Primary Key'
AND		tc.TABLE_SCHEMA		= @DestSchemaName
AND		tc.TABLE_NAME		= @DestTableName;


-- Create Proc Text
SET @SQL =	'CREATE PROCEDURE ' + @DestSchemaName + '.Merge_' + @DestSchemaName + '_' + @DestTableName + CHAR(13) +
'
/***************************************************************
			
Created By:		Raymond F. Betts
Created Date:	' + CONVERT(VARCHAR, CONVERT(DATE, GETDATE())) + CHAR(13) +
'Description:	Merge From ' + @SourceSchemaName + '.' + @SourceTableName + CHAR(13) +
'						To ' + @DestSchemaName + '.' + @DestTableName + CHAR(13) +
'****************************************************************/
AS
BEGIN TRY
	SET XACT_ABORT ON;
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRAN;' + CHAR(13) + CHAR(13);

-- Determine if Identity
SELECT @IsIdentity = c.is_identity
FROM	sys.tables	t
JOIN	sys.schemas	s ON s.schema_id = t.schema_id
JOIN	sys.columns	c ON c.object_id = t.object_id
WHERE	t.name = @DestTableName
AND		s.name = @DestSchemaName
AND		c.name = @PrimaryKey;

IF @IsIdentity = 1
	SET @SQL = @SQL + 'SET IDENTITY_INSERT ' + @DestSchemaName + '.' + @DestTableName + ' ON;' + CHAR(13) + CHAR(13);

	SET @SQL = @SQL + '	MERGE	' +	@DestSchemaName + '.' + @DestTableName + ' Dest' + CHAR(13) +
						'	USING	' + @SourceSchemaName + '.' + @DestTableName + ' Source ON Dest.' + @PrimaryKey + ' = Source.' + @PrimaryKey + CHAR(13) +
																						'		AND Dest.ChangeTrackingID != Source.ChangeTrackingID' + CHAR(13) +
						'	WHEN NOT MATCHED THEN ' + CHAR(13) +
						'	INSERT ' + CHAR(13); 

-- Insert Columns
SET @XML =	(
			SELECT ', ' +  c.name
			FROM	sys.tables	t
			JOIN	sys.schemas	s ON s.schema_id = t.schema_id
			JOIN	sys.columns	c ON c.object_id = t.object_id
			WHERE	t.name = @DestTableName
			AND		s.name = @DestSchemaName	
			AND		c.name != 'ChangeType'
			ORDER BY c.column_id
			FOR XML PATH ('')
			);

SET @SQL  = @SQL + '(' + SUBSTRING(@XML	, 2, LEN(@XML)) + ')' + CHAR(13) + CHAR(13);

SET @SQL = @SQL + 'VALUES ' + CHAR(13);

SET @XML =	(
			SELECT ', Source.' +  c.name
			FROM	sys.tables	t
			JOIN	sys.schemas	s ON s.schema_id = t.schema_id
			JOIN	sys.columns	c ON c.object_id = t.object_id
			WHERE	t.name = @DestTableName
			AND		s.name = @DestSchemaName	
			AND		c.name != 'ChangeType'
			ORDER BY c.column_id
			FOR XML PATH ('')
			);

SET @SQL = @SQL + '(' + SUBSTRING(@XML	, 2, LEN(@XML)) + ');' + CHAR(13) + CHAR(13);

			
-- Update Columns
SET @SQL2 = @SQL2 + ' WHEN MATCHED THEN' + CHAR(13) +
					'UPDATE ' + CHAR(13) +
					'SET		';

SET @XML =	(
			SELECT ', ' +  c.name + ' = Source.' + c.name + CHAR(10)
			FROM	sys.tables	t
			JOIN	sys.schemas	s ON s.schema_id = t.schema_id
			JOIN	sys.columns	c ON c.object_id = t.object_id
			WHERE	t.name = @DestTableName
			AND		s.name = @DestSchemaName
			AND		c.name NOT IN ('IsDeleted', 'ChangeType')	
			AND		(	@IsIdentity = 1
					AND	c.name		!= @PrimaryKey
					)
			ORDER BY c.column_id
			FOR XML PATH ('')
			);

SET @SQL2  = @SQL2 +  SUBSTRING(@XML, 2, LEN(@XML)) + ';' + CHAR(13) + CHAR(13) + CHAR(13);

IF @IsIdentity = 1
	SET @SQL2 = @SQL2 + 'SET IDENTITY_INSERT ' + @DestSchemaName + '.' + @DestTableName + ' OFF;' + CHAR(13) + CHAR(13)
					+ '-- Soft Delete Rows....' + CHAR(13);

-- Delete
SET @SQL3 = @SQL3 + '	UPDATE d
	SET		IsDeleted			= 1
	,		ChangeTrackingID	= s.ChangeTrackingID
	,		BIDateModified		= GETUTCDATE()
	FROM	' + @DestSchemaName + '.' + @DestTableName + ' d' + CHAR(13) +
'	JOIN	' + @SourceSchemaName + '.' + @SourceTableName	+ ' s ON d.' + @PrimaryKey + ' = s.' + @PrimaryKey + CHAR(13) +
																		+ '			AND s.ChangeType = ''d'';' + CHAR(13) + CHAR(13) +
'	COMMIT TRAN;' + CHAR(13) + CHAR(13);																		

SET @SQL3 = @SQL3 +  'END TRY' + CHAR(13) + CHAR(13) 
			+ 'BEGIN CATCH' + CHAR(13)
			+ '	IF @@TRANCOUNT > 1 ROLLBACK TRAN;' + CHAR(13)
			+ '	THROW;' + CHAR(13)
			+ 'END CATCH'

PRINT @SQL;
PRINT @SQL2;
PRINT @SQL3;
