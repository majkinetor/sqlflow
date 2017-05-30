-- sqlflow: connection: admin

--IF EXISTS(SELECT name FROM sys.databases WHERE name = 'test') 
--    DROP DATABASE test
 

CREATE DATABASE test

-- CREATE DATABASE dbName
-- ON (
--   NAME = dbName_dat,
--   FILENAME = 'D:\path\to\dbName.mdf'
-- )
-- LOG ON (
--   NAME = dbName_log,
--   FILENAME = 'D:\path\to\dbName.ldf'
-- )