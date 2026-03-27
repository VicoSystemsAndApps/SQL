-- This enumerates AD group members that map to SQL logins. 
-- Red flags: Broad AD groups that implicitly put many users into sysadmin/server access.

-- Temp table matching xp_logininfo output
IF OBJECT_ID('tempdb..#GroupMembers') IS NOT NULL DROP TABLE #GroupMembers;
IF OBJECT_ID('tempdb..#WinGroups') IS NOT NULL DROP TABLE #WinGroups;

-- List Windows groups with server access
SELECT	name AS WindowsGroup
INTO	#WinGroups
FROM	sys.server_principals
WHERE	type_desc = 'WINDOWS_GROUP';
--AND		name != 'WDH\CTX_SDSProval';

CREATE TABLE #GroupMembers 
(
	account_name		SYSNAME
,	type				NVARCHAR(20)
,	privilege			NVARCHAR(20)
,	mapped_login_name	SYSNAME
,	ad_group			SYSNAME
);

DECLARE @g sysname;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT WindowsGroup FROM #WinGroups;
OPEN c; FETCH NEXT FROM c INTO @g;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	  INSERT	#GroupMembers 
	  EXEC		xp_logininfo @acctname = @g, @option = 'members';
	  FETCH NEXT FROM c INTO @g;
	END
CLOSE c; 
DEALLOCATE c;

SELECT		* 
FROM		#GroupMembers 
--WHERE		permission_path NOT IN ('WDH\Domain Users', 'WDH\BSRS_ResponsiveRepairs', 'WDH\BSRS_TotalMobile', 'WDH\Proval')
ORDER BY	ad_group
,			account_name;
