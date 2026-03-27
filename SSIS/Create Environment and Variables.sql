USE SSISDB
-- Core Vars
DECLARE	@FolderName		VARCHAR(1000) = 'Satsuma'
,		@EnvName		VARCHAR(1000) = 'Production'
,		@FolderID		INT
,		@EnvID			INT
,		@ReturnCode		INT
,		@ErrorMessage	VARCHAR(1000);

-- Variable vars
DECLARE	@AdobeDataReportDays_Name	NVARCHAR(500)	= 'AdobeDataReportDays'
,		@AdobeDataReportDays		INT				= 60
,		@Test_Name					NVARCHAR(500)	= 'RayTest'
,		@Test						NVARCHAR(500)	= 'RayTest';

BEGIN TRY

	BEGIN TRAN;

	-- Folder /////////////////////////////////////////////////////////
	IF EXISTS	(
				SELECT	1
				FROM	catalog.folders
				WHERE	[name] = @FolderName
				) 
	BEGIN
		SELECT	@FolderID = folder_id
		FROM	catalog.folders
		WHERE	[name] = @FolderName;
		PRINT 'Folder ' + @FolderName + ' exists';
	END
	ELSE
	BEGIN
		EXEC catalog.create_folder @FolderName, @FolderID OUTPUT;
		PRINT 'Created Folder ' + @FolderName;
	END
	-- Folder /////////////////////////////////////////////////////////


	-- Environment /////////////////////////////////////////////////////
	IF EXISTS	(
				SELECT	1
				FROM	catalog.environments
				WHERE	[name] = @EnvName
				) 
	BEGIN
		SELECT	@EnvID = environment_id
		FROM	catalog.environments
		WHERE	[name] = @EnvName;

		PRINT 'Environment ' + @EnvName + ' exists';
	END

	ELSE
	BEGIN
		EXEC catalog.create_environment @FolderName, @EnvName;

		SELECT	@EnvID = environment_id
		FROM	catalog.environments
		WHERE	[name] = @EnvName;

		PRINT 'Environment created ' + @EnvName;
	END
	-- Environment /////////////////////////////////////////////////////

	-- Variables /////////////////////////////////////////////////////////////////////////////////////////////////
	IF NOT EXISTS	(
					SELECT	1
					FROM	catalog.environment_variables
					WHERE	environment_id	= @EnvID
					AND		name			= @AdobeDataReportDays_Name
					)
	BEGIN	
		SET @ReturnCode = 0
		EXEC @ReturnCode = catalog.create_environment_variable		@variable_name		= @AdobeDataReportDays_Name
																,	@sensitive			= 0
																,	@description		= N''
																,	@environment_name	= @EnvName
																,	@folder_name		= @FolderName
																,	@value				= @AdobeDataReportDays
																,	@data_type			= N'Int32';
	
		SET @ErrorMessage = 'Issue with creating ' + @AdobeDataReportDays_Name;
		IF @ReturnCode != 0 THROW 51000, @ErrorMessage, 1;
		PRINT 'Variable Created ' + @AdobeDataReportDays_Name;
	END
	ELSE
		PRINT 'Variable ' + @AdobeDataReportDays_Name + ' exists';

	IF NOT EXISTS	(
					SELECT	1
					FROM	catalog.environment_variables
					WHERE	environment_id	= @EnvID
					AND		name			= @Test_Name
					)
	BEGIN	
		SET @ReturnCode = 0
		EXEC @ReturnCode = catalog.create_environment_variable		@variable_name		= @Test_Name
																,	@sensitive			= 0
																,	@description		= N''
																,	@environment_name	= @EnvName
																,	@folder_name		= @FolderName
																,	@value				= @Test
																,	@data_type			= N'String';
	
		SET @ErrorMessage = 'Issue with creating ' + @Test_Name;
		IF @ReturnCode != 0 THROW 51000, @ErrorMessage, 1;
		PRINT 'Variable Created ' + @Test_Name;
	END
	ELSE
		PRINT 'Variable ' + @Test_Name + ' exists';

	-- Variables /////////////////////////////////////////////////////////////////////////////////////////////////

	IF @@TRANCOUNT > 0 COMMIT TRAN;

END TRY

BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	THROW;
END CATCH