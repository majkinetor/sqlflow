IF not exists (select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME='_sqlflow_history')
	CREATE TABLE "_sqlflow_history" (
		RunId	   INT PRIMARY KEY,
		StartDate  datetime2,
		Duration   decimal,
		Config     nvarchar(max),
		Migrations nvarchar(max),
		Changes    nvarchar(max),
		Result	   nvarchar(max)
	);