-- Server role membership
SELECT		spr.name AS LoginName
,			slr.name AS ServerRole
FROM		sys.server_role_members rm
JOIN		sys.server_principals	spr ON rm.member_principal_id	= spr.principal_id
JOIN		sys.server_principals	slr ON rm.role_principal_id		= slr.principal_id
ORDER BY	slr.name
,			spr.name;


