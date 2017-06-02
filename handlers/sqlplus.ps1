class sqlplus {

    [string] $ConnString

    hidden [string] $tmpdir  = "$Env:TEMP/sqlflow/sqlplus"

    sqlplus( [HashTable] $Connection ) {
        if (!(gcm sqlplus -ea 0)) { throw "sqlplus not found on the PATH" }

        $this.ConnString = $Connection.Database
        Write-Verbose "Using sqlplus"
        mkdir -Force $this.tmpdir -ea 0 | Out-Null
    }

    # Run sql file on the connection
    # Return any output and errors in a array (out,err)
    [array] RunFile( [string] $SqlFilePath ) {
        $out = "@$SqlFilePath" | sqlplus -s $this.ConnString
        $out = $out | ? {$_}    #remove blank lines in output
        $errors = $out | Select-String  "SP2-","ORA-"
        return $out, $errors
    }

    # Runs migration history table sql on the connection. Used to insert/update history table.
    # Rows are separated by new lines and columns by spaces. There are no spaces in values.
    # No header should be present.
    # Throws on any error.
    [string] RunSql ( [string] $Sql ) {
        $sqlFile = Join-Path $this.tmpdir "runsql.sql"
        [IO.File]::WriteAllLines($sqlFile, $Sql) # we don't want BOM
        $out, $err = $this.RunFile( $sqlFile )
        if ($err) { throw "Migration history error: $err" }
        return $out
    }
}