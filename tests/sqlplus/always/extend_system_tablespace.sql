BEGIN
FOR c IN (SELECT file_name from dba_data_files where tablespace_name='SYSTEM')
  LOOP
    EXECUTE IMMEDIATE 'alter database datafile '|| '''' ||  c.file_name || '''' ||' '||' autoextend on maxsize unlimited' ;
  END LOOP;
END;
/
   
   
   