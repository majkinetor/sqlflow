function Invoke-Flow( [HashTable]$FlowConfig ) {

    $script:config = $FlowConfig.Clone()
    if ( !$config.Directories) { $config.Directories = @('migrations') }
    if ( !$config.Migrations ) { $config.Migrations = { ls -Directory $config.Directories } }
    $migrations = . $Config.Migrations

    $csFirst = $config.Connections.Keys | select -First 1
    if (!$csFirst) { throw "No connection found" }
    $runner = New-Runner $config.Runner $config.Connections.$csFirst

    $files = foreach ($migration in $migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$config.Files) { continue }
       if ($config.Files.Include) { $f = $f | ? FullName -like $config.Files.Include }
       if ($config.Files.Exclude) { $f = $f | ? FullName -notlike $config.Files.Exclude }
       $f
    }  
    
    foreach ($file in $files) {
        $file.FullName
        $out, $err = $runner.RunFile( $file.FullName )
        if ($err.Count) { @("$($err.Count) errors:") + $err | Write-Warning }
        $out
    }
}

function New-Runner( [string]$Name, $Connection ) {
    if ([string]::IsNullOrEmpty($Name)) { throw "Runner name can't be blank" }
    Write-Verbose "New runner instance: $Name"

    $runner_script = "$PSScriptRoot\runners\$Name.ps1"
    if (!(Test-Path $runner_script )) { throw "Runner not found: $Name"}

    try { . $runner_script } catch { throw "Runner loading error: $_" }

    iex "[$Name]::new( `$Connection )"
}