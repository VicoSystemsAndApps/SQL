/*
    Red flags: TRUSTWORTHY = ON without a strong reason; is_db_chaining_on = 1 across many DBs.

    TRUSTWORTHY ON → potential server-level escalation if database owner maps to a privileged login.
    DB chaining ON → potential lateral privilege escalation between databases.

    In both cases, they weaken the principle of least privilege and should be considered “red flags” during a security review.
*/

SELECT		name AS DatabaseName
,			is_trustworthy_on
,			is_db_chaining_on
FROM		sys.databases
WHERE		database_id > 4
ORDER BY	name;
