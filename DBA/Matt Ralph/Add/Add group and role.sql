
-- Create login for AD group
CREATE LOGIN [WDH\SQL DBA ADMIN] FROM WINDOWS;
 
-- Add AD group to sysadmin fixed server role
ALTER SERVER ROLE [sysadmin] ADD MEMBER [WDH\SQL DBA ADMIN];
