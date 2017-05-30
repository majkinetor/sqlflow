-- sqlflow: connection: admin

IF EXISTS(SELECT name FROM sys.databases WHERE name = 'test') 
   DROP DATABASE test
