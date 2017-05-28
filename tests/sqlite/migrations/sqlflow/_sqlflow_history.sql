CREATE TABLE "_sqlflow_history" (
	RunId	  INTEGER PRIMARY KEY DESC,
	StartDate  varchar,
	EndDate    varchar,
	Config     varchar,
	Migrations varchar,
	Changes    varchar,
	Result	   varchar
);