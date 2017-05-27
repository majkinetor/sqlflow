class sqlite_shell {
    [string] $DatabasePath

    hidden [string] $errorFile = "$Env:TEMP\sqlflow\sqlite_shell.err"
    hidden [string] $exeName   = 'sqlite3'

    sqlite_shell( [string] $Connection ) {
        if (!(gcm $this.exeName -ea 0)) { throw "$($this.exeName) not found on the PATH" }
        $this.DatabasePath = $Connection
        Write-Verbose "Using sqlite_shell with database: $Connection"
    }

    RemoveDatabase() {
        rm $this.DatabasePath -ea 0
        if (Test-Path $this.DatabasePath) { rm $this.DatabasePath }
    }

    [array] RunFile( [string] $SqlFilePath ) {

        $cmd = "{0} {1} "".read '{2}'"" 2>{3}" -f  $this.exeName, $this.DatabasePath, $SqlFilePath, $this.errorFile

        # Execute via cmd.exe as errors messages are cut in the middle without cmd.exe
        # This looks like Powershell 5 bug, should try in 6 if its resolved
        Write-Verbose "RunFile: $cmd"
        $out = cmd.exe /C $cmd
        $errors = gc $this.ErrorFile
        return $out, $errors
    }
}

# $VerbosePreference = 'continue'
# $file = 'C:\Work\sqlflow\tests\sqlite\migrations\01 init schema\humans.sql'
# $db = 'C:\Work\sqlflow\tests\sqlite\testdb'

# $se = iex "[sqlite_shell]::new('$db')"
# $se.RunFile( $file )
