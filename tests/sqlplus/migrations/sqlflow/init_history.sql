CREATE TABLE "_sqlflow_history" (
    RunId	   INTEGER,
    StartDate  varchar(50),
    Duration   number(10,2),
    Migrations nclob,
    Changes    nclob,
    Result	   nclob,
    CONSTRAINT PK_RUNID PRIMARY KEY (RunId)
);