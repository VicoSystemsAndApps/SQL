USE YourDatabaseName;  
GO

-- Create user if not exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'MYAD\data_reader')
    CREATE USER [MYAD\data_reader] FOR LOGIN [MYAD\data_reader];
GO

-- Grant read access
GRANT SELECT TO [MYAD\data_reader];

-- Grant stored procedure/function execution
GRANT EXECUTE TO [MYAD\data_reader];
GO