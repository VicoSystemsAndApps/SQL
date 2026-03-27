/*
SQL_D365PROD
sql_dba_admin
SQL_Node4_ADMIN
SQL_D365sqlprod_Leavers
*/


USE master;

-- Create login for AD group
CREATE LOGIN [WDH\SQL_D365PROD] FROM WINDOWS;
 
-- Add AD group to sysadmin fixed server role
ALTER SERVER ROLE [sysadmin] ADD MEMBER [WDH\SQL_D365PROD];

-- disable
ALTER LOGIN [WDH\SQL_Server_Admin] DISABLE;
ALTER LOGIN [WDH\SQLServerDatabaseAdministrators] DISABLE;

REVOKE CONNECT SQL FROM [WDH\SQL_Server_Admin];
REVOKE CONNECT SQL FROM [WDH\SQLServerDatabaseAdministrators];