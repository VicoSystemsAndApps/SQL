-- DB's by Agent Job ----------------------------
SELECT DISTINCT     s.database_name
FROM                msdb.dbo.sysjobsteps AS s
WHERE               s.database_name IS NOT NULL
ORDER BY            s.database_name;


-- Jobs and DB in each Step ---------------------
SELECT		j.job_id
,			j.name AS JobName
,			s.step_id
,			s.step_name
,			s.subsystem
,			s.database_name
FROM		msdb.dbo.sysjobs		j
JOIN		msdb.dbo.sysjobsteps	s ON j.job_id = s.job_id
ORDER BY	j.name
,			s.step_id;

-- DB's in any Inline T-SQL ------------------------
SELECT      j.name                  AS JobName
,           s.step_id
,           s.step_name
,           s.database_name         AS JobDatabase
,           CASE    WHEN s.command LIKE '%USE [%]%' OR s.command LIKE '%USE %' 
                        THEN 'Possibly sets database via USE statement'
                    WHEN s.command LIKE '%].dbo.%' OR s.command LIKE '%.dbo.%'
                        THEN 'References 3-part DB names'
                    ELSE 'N/A'
            END                     AS DatabaseReferenceType
,           s.command
FROM        msdb.dbo.sysjobs        j
JOIN        msdb.dbo.sysjobsteps    s   ON j.job_id = s.job_id
WHERE       s.subsystem = 'TSQL'
ORDER BY    j.name
,           s.step_id;

