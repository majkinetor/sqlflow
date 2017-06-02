class sqlcmd {
    [string] $Server    = 'localhost'
    [int]    $Port      = 1433
    [string] $Username
    [string] $Password
    [string] $Database
    [int]    $Timeout
    [bool]   $Trusted   = $false

    hidden [string] $tmpdir  = "$Env:TEMP/sqlflow/sqlcmd"

    sqlcmd( [HashTable] $Connection ) {
        if (!(gcm 'Invoke-SqlCmd' -ea 0)) { throw "Cmdlet Invoke-SqlCmd not found" }

        if (!$Connection.Database) { 'throw Database must be specified' }
        $sql_auth = !([string]::IsNullOrWhiteSpace($Connection.Username) -or [string]::IsNullOrWhiteSpace($Connection.Password))
        if ( !$sql_auth -and !$Connection.Trusted) { throw 'Either username/password or trusted connection must be set'}
              
        if (![string]::IsNullOrWhiteSpace($Connection.Server)) { $this.Server = $Connection.Server.Trim() }
        if (![string]::IsNullOrWhiteSpace($Connection.Port))   { $this.Port = $Connection.Port }
        $this.Username = ($Connection.Username -as [string]).Trim()
        $this.Password = $Connection.Password
        $this.Database = ($Connection.Database -as [string]).Trim()
        $this.Timeout  = $Connection.Timeout
        if ($Connection.Trusted -is [bool]) { $this.Trusted = $Connection.Trusted } else {
            if (!$sql_auth) { $this.Trusted = $true }
        }
        
        Write-Verbose "Using sqlcmd with database $($this.Server):$($this.Port)\$($this.Database)"
        Write-Verbose $( if ($this.Trusted) { "Trusted connection" } else { "User: " + $this.Username } )

        mkdir -Force $this.tmpdir -ea 0 | Out-Null
    }

    # Run sql file on the connection
    # Return any output and errors in a array ($out, $err) which are both [string[]]
    # $out can't be null
    [array] RunFile( [string] $SqlFilePath ) {
        $errorFile = Join-Path $this.tmpdir "runfile.err"

        $params = @{
            ServerInstance  = "{0},{1}" -f $this.Server, $this.Port
            Database        = $this.Database
            InputFile       = $SqlFilePath
        }

        if (!$this.Trusted) { $params.Username = $this.Username;  $params.Password = $this.Password }
        if ($this.Timeout)  { $params.Timeout = $this.Timeout }

        $out = Invoke-Sqlcmd @params 2> $errorFile
        if (!$out) { $out = '' }  # prevent $null in $out
        $err_re = '^Invoke-Sqlcmd : '
        $err = ((gc $errorFile) -match $err_re) -replace $err_re
        return $out,$err
    }

    # Runs migration history table sql on the connection. Used to insert/update history table.
    # Rows are separated by new lines and columns by spaces. There are no spaces in values.
    # No header should be present. NULL is returned as 'NULL' string.
    # Throws on any error.
    [string] RunSql ( [string] $Sql ) {
        $Sql = "set nocount on;`n$Sql"
        $sqlFile = Join-Path $this.tmpdir "runsql.sql"
        [IO.File]::WriteAllLines($sqlFile, $Sql) # we don't want BOM
        $out, $err = $this.RunFile( $sqlFile )
        if ($err) { throw "Migration history error: $err" }
        $row = ''
        $out.Table.Columns.Caption | % { $row += ' ' + $(if ($out.$_ -isnot [DBNull]) { $out.$_ } else {'NULL'}) }
        return $row.Substring(1)
    }
}