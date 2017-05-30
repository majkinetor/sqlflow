CREATE TABLE "_sqlflow_history" (
	RunId	   INT PRIMARY KEY,
	StartDate  datetime2,
	Duration   decimal,
	Config     nvarchar(max),
	Migrations nvarchar(max),
	Changes    nvarchar(max),
	Result	   nvarchar(max)
);