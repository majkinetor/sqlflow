--|sqlflow| connection: admin

Use test
GO

IF NOT EXISTS (SELECT * FROM master.sys.server_principals WHERE name = 'test')
BEGIN
    CREATE LOGIN test
        WITH PASSWORD    = N'test',
        CHECK_POLICY     = OFF,
        CHECK_EXPIRATION = OFF;
END

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'test')
BEGIN
    CREATE USER [test] FOR LOGIN [test]
    EXEC sp_addrolemember N'db_ddladmin',   N'test'
	EXEC sp_addrolemember N'db_datawriter', N'test'
	EXEC sp_addrolemember N'db_datareader', N'test'
END