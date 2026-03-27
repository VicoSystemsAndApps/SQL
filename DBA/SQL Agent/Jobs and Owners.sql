
-- Jobs and Owners
SELECT		j.name						AS JobName
,			SUSER_SNAME(j.owner_sid)	AS JobOwner
,			j.enabled
FROM		msdb.dbo.sysjobs j
ORDER BY	j.name;

-- Job Proxies (who own proxies)
SELECT		p.name AS ProxyName
,			sp.name AS PrincipalName
FROM		msdb.dbo.sysproxylogin	pl
JOIN		msdb.dbo.sysproxies		p	ON p.proxy_id	= pl.proxy_id
JOIN		sys.server_principals	sp	ON sp.sid		= pl.sid
ORDER BY	p.name
,			sp.name;

-- Agent fixed database roles (who is SQLAgentUser/Reader/Operator)
SELECT		dp.name AS DbUser
,			r.name  AS AgentRole
FROM		msdb.sys.database_role_members drm
JOIN		msdb.sys.database_principals r  ON r.principal_id = drm.role_principal_id
JOIN		msdb.sys.database_principals dp ON dp.principal_id = drm.member_principal_id
WHERE		r.name IN ('SQLAgentUserRole','SQLAgentReaderRole','SQLAgentOperatorRole')
ORDER BY	dp.name
,			r.name;

