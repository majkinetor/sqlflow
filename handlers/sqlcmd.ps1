class sqlcmd {

    [string] $Server    = 'localhost'
    [int]    $Port      = 1433
    [string] $Username
    [string] $Password
    [string] $Database
    [bool]   $Trusted   = $false

    hidden [string] $tmpdir  = "$Env:TEMP/sqlflow/sqlcmd"
    hidden [string] $exeName = 'sqlcmd'

    sqlcmd( [HashTable] $Connection ) {
        if (!(gcm $this.exeName -ea 0)) { throw "$($this.exeName) not found on the PATH" }

        if (!$Connection.Database) { 'throw Database must be specified' }
        if ( ([string]::IsNullOrWhiteSpace($Connection.Username) -or [string]::IsNullOrWhiteSpace($Connection.Password)) `
              -and !$Connection.Trusted) { throw 'Either username/password or trusted connection must be set'}
              
        if (![string]::IsNullOrWhiteSpace($Connection.Server)) { $this.Server = $Connection.Server.Trim() }
        if (![string]::IsNullOrWhiteSpace($Connection.Port))   { $this.Port = $Connection.Port }
        $this.Username = ($Connection.Username -as [string]).Trim()
        $this.Password = $Connection.Password
        $this.Database = ($Connection.Database -as [string]).Trim()
        if ($Connection.Trusted -is [bool]) { $this.Trusted = $Connection.Trusted }
        
        Write-Verbose "Using sqlcmd with database $($this.Server):$($this.Port)\$($this.Database)"
        Write-Verbose ( if ($this.Trusted) { "Trusted connection" } else { "User: " + $this.Username } )

        mkdir -Force $this.tmpdir -ea 0 | Out-Null
    }

    RemoveDatabase() {
    }

    # Run sql file on the connection
    # Return any output and errors in a array (out,err)
    [array] RunFile( [string] $SqlFilePath ) {

        $outFile = Join-Path $this.tmpdir "runfile.err"
        $cmd = "{0} -S '{1},{2}' -i '{3}'" -f  $this.exeName, $this.Server, $this.Port, $this.DatabasePath, $SqlFilePath, $outFile

        # Execute via cmd.exe as errors messages are cut in the middle without cmd.exe
        # This looks like Powershell 5 bug, should try in 6 if its resolved
        Write-Verbose "RunFile: $cmd"
        $out = . $cmd
        $errors = ''
        return $out, $errors
    }

    # Run sql string on the connetion
    # Return ($out, $err)
    # Output must be in csv format
    [array] RunSql ( [string] $Sql ) {
        $Sql = ".header on`n.mode csv`n$Sql"
        $sqlFile = Join-Path $this.tmpdir "runsql.sql"
        [IO.File]::WriteAllLines($sqlFile, $Sql) # we don't want BOM
        $out, $err = $this.RunFile( $sqlFile )
        if ($out) { $out = $out | Out-String | ConvertFrom-CSV }
        return $out, $err
    }

    # Returns if table exists 
    # There is no universal SQL for this, depends on handler
    # Used with HistoryTable.
    [bool] TableExists( [string] $TableName ) {
        $_, $err= $this.RunSql( "select * from $TableName where 1=2" );
        if (!$err) { return $true }

        return ($err -notlike '*no such table*')
    }
}

# $VerbosePreference = 'continue'
# $file = 'C:\Work\sqlflow\tests\sqlite\migrations\01 init schema\humans.sql'
# $db = 'C:\Work\sqlflow\tests\sqlite\testdb'

# $se = iex "[sqlite_shell]::new('$db')"
# $se.RunFile( $file )
