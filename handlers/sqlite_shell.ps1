class sqlite_shell {
    [string] $DatabasePath

    hidden [string] $tmpdir  = "$Env:TEMP/sqlflow/sqlite"
    hidden [string] $exeName = 'sqlite3'

    sqlite_shell( [string] $Connection ) {
        if (!(gcm $this.exeName -ea 0)) { throw "$($this.exeName) not found on the PATH" }
        $this.DatabasePath = $Connection
        Write-Verbose "Using sqlite_shell with database: $Connection"

        mkdir -Force $this.tmpdir -ea 0 | Out-Null
    }

    RemoveDatabase() {
        rm $this.DatabasePath -ea 0
        if (Test-Path $this.DatabasePath) { rm $this.DatabasePath }
    }

    # Run sql file on the connection
    # Return any output and errors in a array (out,err)
    [array] RunFile( [string] $SqlFilePath ) {

        $errorFile = Join-Path $this.tmpdir "runfile.err"
        $cmd = "{0} {1} "".read '{2}'"" 2>{3}" -f  $this.exeName, $this.DatabasePath, $SqlFilePath, $errorFile

        # Execute via cmd.exe as errors messages are cut in the middle without cmd.exe
        # This looks like Powershell 5 bug, should try in 6 if its resolved
        Write-Verbose "RunFile: $cmd"
        $out = cmd.exe /C $cmd
        $errors = gc $errorFile
        return $out, $errors
    }

    # Run sql string on the connetion
    # Return ($out, $err)
    # Output must be in csv format
    [array] RunSql ( [string] $Sql ) {
        $Sql = ".mode csv`n$Sql"
        $sqlFile = Join-Path $this.tmpdir "runsql.sql"
        [IO.File]::WriteAllLines($sqlFile, $Sql) # we don't want BOM
        return $this.RunFile( $sqlFile )
    }

    # Returns if table exists 
    # There is no universal SQL for this, depends on handler
    # Used with HistoryTable.
    [bool] TableExists( [string] $TableName ) {
        $_, $err= $this.RunSql( "select * from $TableName where 1=2" );
        return ($err -notlike '*no such table*')
    }
}

# $VerbosePreference = 'continue'
# $file = 'C:\Work\sqlflow\tests\sqlite\migrations\01 init schema\humans.sql'
# $db = 'C:\Work\sqlflow\tests\sqlite\testdb'

# $se = iex "[sqlite_shell]::new('$db')"
# $se.RunFile( $file )
