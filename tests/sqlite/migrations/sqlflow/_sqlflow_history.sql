CREATE TABLE IF NOT EXISTS "_sqlflow_history" (
	RunId	   INTEGER PRIMARY KEY DESC,
	StartDate  varchar,
	Duration   INTEGER,
	Config     varchar,
	Migrations varchar,
	Changes    varchar,
	Result	   varchar
);