-- Create login for AD group
CREATE LOGIN [WDH\SQL_Node4_ADMIN] FROM WINDOWS;
 
-- Add AD group to sysadmin fixed server role
ALTER SERVER ROLE [sysadmin] ADD MEMBER [WDH\SQL_Node4_ADMIN];

-- Create login for AD group
CREATE LOGIN [WDH\SQL DBA Admin] FROM WINDOWS;
 
-- Add AD group to sysadmin fixed server role
ALTER SERVER ROLE [sysadmin] ADD MEMBER [WDH\SQL DBA Admin];


================================================================
-- Create login for AD group
CREATE LOGIN [WDH\[AD-GROUPNAME] FROM WINDOWS;
 
-- Add AD group to sysadmin fixed server role
ALTER SERVER ROLE [sysadmin] ADD MEMBER [WDH\[AD-GROUPNAME];