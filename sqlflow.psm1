function Invoke-Flow( [HashTable]$FlowConfig ) {

    $config = $FlowConfig.Clone()
    if ( !$config.Directories) { $config.Directories = @('migrations') }
    if ( !$config.Migrations ) { $config.Migrations = { ls -Directory $config.Directories } }
    $migrations = . $Config.Migrations

    if (!$config.Runner) { throw 'No runner specified' }
    $runner_script = "$PSScriptRoot/runners/{0}.ps1" -f $config.Runner
    if (!(Test-Path $runner_script )) { throw "Runner not found: $config.Runner"}
    try { . $runner_script } catch { throw "Runner loading error: $_" }

    $csFirst = $config.ConnectionStrings.Keys | select -First 1
    if (!$csFirst)  { throw "No connection string found" }
    $csFirst = $config.ConnectionStrings.$csFirst

    Write-Verbose "Creating runner instance"
    $e = '[{0}]::new( "{1}" )' -f $config.Runner, $csFirst
    $script:runner = iex $e

    $files = foreach ($migration in $migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$config.Files) { continue }
       if ($config.Files.Include) { $f = $f | ? FullName -like $config.Files.Include }
       if ($config.Files.Exclude) { $f = $f | ? FullName -notlike $config.Files.Exclude }
       $f
    }  
    
    foreach ($file in $files) {
        $file.FullName
        $out, $err = $script:runner.RunFile( $file.FullName )
        if ($err.Count) { @("$($err.Count) errors:") + $err | Write-Warning }
        $out
    }

}