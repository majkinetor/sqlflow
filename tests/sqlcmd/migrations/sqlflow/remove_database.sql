-- sqlflow: connection: admin

IF EXISTS(SELECT name FROM master.sys.databases WHERE name = 'test') 
    ALTER DATABASE [test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE test
