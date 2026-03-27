EXEC sp_helpserver;

-- Linked Server and Provider
SELECT		name AS LinkedServer
,			product
,			provider
,			data_source
,			is_linked
FROM		sys.servers
WHERE		is_linked = 1
ORDER BY	name;


-- Security Mappings
SELECT		s.name					AS LinkedServer
,			sp.name					AS LocalLogin
,			l.remote_name			AS RemoteUser
,			l.uses_self_credential	AS UsesSelf
FROM		sys.linked_logins		l
JOIN		sys.servers				s	ON s.server_id		= l.server_id
LEFT JOIN	sys.server_principals	sp	ON sp.principal_id	= l.local_principal_id
ORDER BY	s.name
,			sp.name;