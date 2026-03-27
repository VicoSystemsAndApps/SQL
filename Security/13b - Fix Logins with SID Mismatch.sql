
USE [DocumotiveDMS];
GO

SELECT      dp.name AS DbUser
,           dp.sid AS DbUserSid
,           sp.name AS ServerLogin
,           sp.sid AS ServerSid
FROM        sys.database_principals dp
LEFT JOIN   sys.server_principals sp ON sp.name  COLLATE DATABASE_DEFAULT = dp.name  COLLATE DATABASE_DEFAULT
WHERE       dp.name = N'documotivers2';


ALTER USER documotivers2 WITH LOGIN = documotivers2;
GO

SELECT      dp.name AS DbUser
,           dp.sid AS DbUserSid
,           sp.name AS ServerLogin
,           sp.sid AS ServerSid
FROM        sys.database_principals dp
LEFT JOIN   sys.server_principals sp ON sp.name  COLLATE DATABASE_DEFAULT = dp.name  COLLATE DATABASE_DEFAULT
WHERE       dp.name = N'documotivers2';