-- Powerful GRANTs even without role membership
-- Red flags: CONTROL SERVER, IMPERSONATE ANY LOGIN.

SELECT      pr.name         AS Grantee
,           pr.type_desc    AS PrincipalType
,           pe.state_desc
,           pe.permission_name
FROM        sys.server_permissions  pe
JOIN        sys.server_principals   pr ON pr.principal_id = pe.grantee_principal_id
WHERE       (
                pe.state IN ('W', 'G','W') 
            OR  pe.state_desc LIKE 'GRANT%'   -- GRANT or GRANT_WITH_GRANT_OPTION
            )
AND         pe.permission_name IN   (
                                    'CONTROL SERVER','ALTER ANY LOGIN','IMPERSONATE ANY LOGIN'
                                , 'VIEW SERVER STATE','ALTER ANY CREDENTIAL','ALTER ANY SERVER ROLE'
                                )
AND         NOT (pr.type_desc = 'CERTIFICATE_MAPPED_LOGIN' AND pr.name LIKE '##MS_%')
ORDER BY    pe.permission_name
,           Grantee;
