-- Red flags: xp_cmdshell = 1, cross db ownership chaining = 1, CLR strict security = 0.

SELECT		name
,			value_in_use
FROM		sys.configurations
WHERE		name IN (
					  'xp_cmdshell'
					,  'Ole Automation Procedures'
					,  'Ad Hoc Distributed Queries'
					,  'cross db ownership chaining'
					,  'CLR strict security'    -- 0 can be risky with UNSAFE assemblies
					)
ORDER BY	name;
