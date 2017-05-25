$config = @{
    Runner         = 'sqlite_shell'
    HistoryTable   = '_sqlflow_table'

    # Directories     = @{
    #     Migrations = 'Patches'
    #     SqlDirs    = 'ddl', 'dml', 'plsql'
    #     PlSqlDir   = 'source\TrezorMaster\TrezorPlsq'
    #     Compile    = 'model\COMPILE'
    # }

    Directories = @(
        'migrations'
    )

    Files = @{
        Include  = '*.sql'
        Exclude  = '~*'
    }

    'Get-Migrations' = {
        ls -Directory $config.Directories
    }

    ConnectionStrings = @{
        test = "test.db"
    }

    # ConnectionStrings = @{
    #     user  = "${Hostname}:$Port/$Sid"
    #     admin = "${Hostname}:$Port/$Sid as sysdba"
    # }
}
