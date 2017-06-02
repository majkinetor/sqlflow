--|sqlflow| connection: admin

-- args 1=user, 2=password

DECLARE cnt NUMBER;
BEGIN
  SELECT count(*) INTO cnt FROM dba_users WHERE UPPER(username)='TEST';
  IF cnt = 0 THEN
    CREATE USER test IDENTIFIED BY test;
    GRANT CONNECT TO test;
    GRANT CONNECT,RESOURCE,DBA TO test;
    GRANT CREATE SESSION, GRANT ANY PRIVILEGE TO test;
    GRANT UNLIMITED TABLESPACE TO test;
    GRANT CREATE ANY DIRECTORY TO test;
    GRANT EXECUTE ON SYS.UTL_FILE TO test;
    GRANT EXECUTE ON SYS.DBMS_LOCK TO test;
    GRANT SELECT ON v_$session TO test;
    GRANT ALTER SYSTEM TO test;
  END IF;
END;
/
