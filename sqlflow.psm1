function Invoke-Flow( [HashTable]$FlowConfig ) {

    set-Config $FlowConfig
    
    $migrations = . $Config.Migrations
    $files  = get-MigrationFiles $migrations

    $csFirst = $config.Connections.Keys | select -First 1
    if (!$csFirst) { throw "No connection found" }
    $runner = New-Runner $config.Runner $config.Connections.$csFirst

    run-Files $runner $files
}

function set-Config([HashTable] $UserConfig) {
    $script:config = $UserConfig.Clone()
    if ( !$config.Directories) { $config.Directories = @('migrations') }
    if ( !$config.Migrations ) { $config.Migrations = { ls -Directory $config.Directories } }
}

function run-Files( $runner, $Files ) {
    foreach ($file in $files) {
        $file.FullName
        $out, $err = $runner.RunFile( $file.FullName )
        if ($err.Count) { @("$($err.Count) errors:") + $err | Write-Warning }
        $out
    }
}

function get-MigrationFiles( $Migrations ) {
    $files = foreach ($migration in $Migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$script:config.Files) { continue }
       if ($script:config.Files.Include) { $f = $f | ? FullName -like $script:config.Files.Include }
       if ($script:config.Files.Exclude) { $f = $f | ? FullName -notlike $script:config.Files.Exclude }
       $f
    }  
    $files
}

function New-Runner( [string]$Name, $Connection ) {
    if ([string]::IsNullOrEmpty($Name)) { throw "Runner name can't be blank" }
    Write-Verbose "New runner instance: $Name"

    $runner_script = "$PSScriptRoot\runners\$Name.ps1"
    if (!(Test-Path $runner_script )) { throw "Runner not found: $Name"}

    try { . $runner_script } catch { throw "Runner loading error: $_" }

    iex "[$Name]::new( `$Connection )"
}   


Export-ModuleMember -Function 'Invoke-Flow', 'New-Runner'