--|sqlflow| connection: admin

-- :setvar SQLCMDERRORLEVEL 1
-- USE test
-- GO
-- :setvar SQLCMDERRORLEVEL 0

IF not exists (select * from test.INFORMATION_SCHEMA.TABLES where TABLE_NAME='_sqlflow_history')
BEGIN
	CREATE TABLE test.dbo._sqlflow_history (
		RunId	   INT PRIMARY KEY,
		StartDate  nvarchar(50),
		Duration   decimal(18,2),
		Migrations nvarchar(max),
		Changes    nvarchar(max),
		Result	   nvarchar(max)
	);
	PRINT 'Created table _sqlflow_history'
END