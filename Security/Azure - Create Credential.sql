/***************************************************************************
Used to create a Credential in SQL Server Allowing you to backup to Azure Blob Storage. 
You can also use this Credential to restore from Azure Blob Storage.

Steps:
1 - Create a Storage Account in Azure Portal
2 - Create a Container in the Storage Account e.g. backups
3 - Create a Shared Access Signature (SAS) for the Container with Write and List permissions
4 - Run the below code to create a Credential in SQL Server using the Storage Account Name, Container Name and SAS Key
    NB populate variables
5 - Use the Credential to backup or restore databases to/from Azure Blob Storage (optional code provided at the end of the script)

***************************************************************************/
DECLARE     @Date               AS NVARCHAR(25)
,           @TSQL               AS NVARCHAR(MAX)
,           @ContainerName      AS NVARCHAR(MAX)
,           @StorageAccountName AS VARCHAR(MAX)
,           @SASKey             AS VARCHAR(MAX)
,           @DatabaseName       AS SYSNAME;


SELECT @Date                = REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 100), '  ', '_'), ' ', '_'), '-', '_'), ':', '_');
SELECT @StorageAccountName  = ''; --- Find this from Azure Portal
SELECT @ContainerName       = ''; --- Find this from Azure Portal
SELECT @SASKey              = ''; --- Find this from Azure Portal
SELECT @DatabaseName        = 'master';

IF NOT EXISTS 
(
SELECT  1
FROM    sys.credentials
WHERE   name = '''https://' + @StorageAccountName + '.blob.core.windows.net/' + @ContainerName + ''''
)
BEGIN
    SELECT @TSQL = 'CREATE CREDENTIAL [https://' + @StorageAccountName + '.blob.core.windows.net/' + @ContainerName + '] WITH IDENTITY = ''SHARED ACCESS SIGNATURE'', SECRET = ''' + REPLACE(@SASKey, '?sv=', 'sv=') + ''';'
    SELECT @TSQL
    --EXEC (@TSQL)
END

/*
Test Backup if you want to try (Uncomment to run)

    SELECT @TSQL = 'BACKUP DATABASE [' + @DatabaseName + '] TO '
    SELECT @TSQL += 'URL = N''https://' + @StorageAccountName + '.blob.core.windows.net/' + @ContainerName + '/' + @DatabaseName + '_' + @Date + '.bak'''
    SELECT @TSQL += ' WITH COMPRESSION, MAXTRANSFERSIZE = 4194304, BLOCKSIZE = 65536, CHECKSUM, FORMAT, STATS = 1;'
    SELECT @TSQL
    --EXEC (@TSQL)
*/