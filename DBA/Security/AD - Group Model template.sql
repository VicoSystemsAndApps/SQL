Example Groups

--# Global (applies to all instances)
WDH\SQL_GLOBAL_DBA           -- sysadmin on all SQL Servers
WDH\SQL_GLOBAL_MONITOR       -- VIEW SERVER STATE, VIEW ANY DEFINITION

-- Per environment (optional)
WDH\SQL_PROD_RO
WDH\SQL_PROD_RW
WDH\SQL_NONPROD_RO
WDH\SQL_NONPROD_RW

--# Per server (for exceptions / least-privilege)
WDH\SQL_SRV01_ADMIN          -- (usually empty; rely on GLOBAL_DBA)
WDH\SQL_SRV01_RO
WDH\SQL_SRV01_RW
WDH\SQL_SRV01_MONITOR
