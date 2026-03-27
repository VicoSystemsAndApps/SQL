SELECT  'CREATE CREDENTIAL [' + name + '] WITH IDENTITY = N''' +
        credential_identity + ''';' AS CreateStatement
FROM    sys.credentials;
