USE YourDatabaseName; 
GO

-- Create user if not exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'MYAD\data_writer')
    CREATE USER [MYAD\data_writer] FOR LOGIN [MYAD\data_writer];
GO

-- Grant read/write permissions
GRANT SELECT, INSERT, UPDATE, DELETE TO [MYAD\data_writer];

-- Grant stored procedure/function execution
GRANT EXECUTE TO [MYAD\data_writer];
GO