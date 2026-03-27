SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

EXEC sp_SpaceUsed 'EDA_TENANT1.APPLICATION';

DECLARE	@Data			DECIMAL(15,1)	= 2832872             
,		@Rows			DECIMAL(15,1)	= 2294670                                                              
,		@Buffer			DECIMAL(15,1)
,		@RowSize		DECIMAL(15,1)
,		@RowSize100		DECIMAL(15,1)
,		@Buffer100		DECIMAL(15,1)	= 104857600;


SET @Buffer = (@Data * 1024) / @Rows;
SELECT 'Buffer Size ' + CONVERT(VARCHAR, @Buffer); -- DefaultBufferMaxRows

SET @RowSize = @Rows / @Data * 1024;
SELECT 'Rows for set buffer ' + CONVERT(VARCHAR, @RowSize); -- DefaultBufferSize

-- If you set the Buffer to MAX 100MB - wise for bigger tables
SET @RowSize100 = (@Buffer100 / @RowSize);
SELECT 'Rows for 100MB Buffer ' +  CONVERT(VARCHAR, @RowSize100); -- DefaultBufferMaxRows 


DECLARE @BufferSize INT				= 10485760
,		@TableName	VARCHAR(200)	= 'Table'
,		@SchemaName VARCHAR(50)		= 'Schema';

WITH RowByteSize AS
(
	SELECT	SUM(max_length) AS	RowLength
	FROM	sys.tables	t
	JOIN	sys.columns c	ON t.object_id = c.object_id
	JOIN	sys.schemas s	ON t.schema_id = s.schema_id
	WHERE	t.name = @TableName
	AND		s.name = @SchemaName
)
SELECT	@BufferSize / RowLength AS DefaultBufferRows
FROM	RowByteSize;
