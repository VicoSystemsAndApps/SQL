-- Disabled, policy/expiration, default DB existence
-- Red flags: is_policy_checked = 0, is_expiration_checked = 0, default DBs that no longer exist, disabled sa re-enabled.

-- Policy & expiration
SELECT      name
,           is_disabled
,           is_policy_checked
,           is_expiration_checked
FROM        sys.sql_logins
WHERE       name   NOT LIKE '##MS_%'   -- exclude system cert logins
ORDER BY    name;

-- Default DBs that don't exist (all principals)
SELECT      p.name
,           p.type_desc
,           p.default_database_name
FROM        sys.server_principals p
LEFT JOIN   sys.databases d ON d.name = p.default_database_name
WHERE       p.type_desc                 IN ('SQL_LOGIN','WINDOWS_LOGIN','WINDOWS_GROUP')
AND         (   p.default_database_name IS NOT NULL 
            AND d.name                  IS NULL
            );
