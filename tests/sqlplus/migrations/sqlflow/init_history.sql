DECLARE cnt NUMBER;
BEGIN
  SELECT count(*) INTO cnt FROM all_tables WHERE table_name = '_sqlflow_history';
  IF cnt = 0 THEN  
    EXECUTE IMMEDIATE 'CREATE TABLE "_sqlflow_history" (
        RunId	   INTEGER,
        StartDate  varchar(50),
        Duration   number(10,2),
        Migrations nclob,
        Changes    nclob,
        Result	   nclob,
        CONSTRAINT PK_RUNID2 PRIMARY KEY (RunId)
    )';
  END IF;
END;