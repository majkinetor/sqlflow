function Invoke-Flow {
    param(
        # Sqlflow migration config
        [HashTable]$FlowConfig, 

        # Remove database before start to apply all migrations
        [switch] $Reset 
    )

    set-Config $FlowConfig
    
    $script:startTime = Get-Date
    log ( "Started {0} version {1}`n  at {2}`n  by {3}`n" -f $module.Name, $module.Version, $startTime.ToString($config.DateFormat), "$Env:USERDOMAIN\$Env:USERNAME@$Env:COMPUTERNAME" )
    
    $migrations = . $Config.Migrations
    $mf  = get-MigrationFiles $migrations

    $csFirst = $config.Connections.Keys | select -First 1
    if (!$csFirst) { throw "No connection found" }
    $handler = New-Handler $config.Handler $config.Connections.$csFirst
    if ( $Reset ) {  Write-Warning "Reseting database"; $handler.RemoveDatabase() }

    run-Files $handler $mf
}

function set-Config([HashTable] $UserConfig) {
    $script:config = $UserConfig.Clone()
    if ( !$config.Directories) { $config.Directories = @('migrations') }
    if ( !$config.Migrations ) { $config.Migrations = { ls -Directory $config.Directories } }
}

function run-Files( $handler, $MigrationFiles ) {
    $stats = [ordered]@{ Time = ''; Files = 0; Errors = 0 }
    foreach ($mf in $MigrationFiles) 
    { 
        $fcount = $mf.files.Count
        $migration_errors = 0
        $start = Get-Date
        log -Header '',("Starting migration '{0}' - {1} files" -f $mf.migration.Name, $fcount  )
        for ($i=1; $i -le $mf.files.Count; $i++)
        {
            $file = $mf.files[$i-1]          
            log ('{0}/{1} {2}' -f "$i".PadLeft(3), "$fcount".PadRight(3), $file.FullName)
            $out, $err = $handler.RunFile( $file.FullName )
            if ($err.Count) { @("Errors: $($err.Count)") + $err | Write-Warning }
            $migration_errors += $err.Count
            $out
        }
        log -Header ( "Finished migration '{0}' after {1:f2} minutes - errors: {2}" -f $mf.migration.Name, ((Get-Date)-$start).TotalMinutes, $migration_errors)
        $stats.files  += $fcount
        $stats.errors += $migration_errors
    }

    log -Header ("`nFinished {0} migrations" -f $mf.Count)
    $stats.time = ( (Get-Date) - $script:startTime ).TotalMinutes.ToString("#.##") + ' minutes'
    $stats.Keys | % { log "  $(${_}.PadRight(15)) $($stats.$_)"}
}

function get-MigrationFiles( $Migrations ) {
    $mf = foreach ($migration in $Migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$script:config.Files) { continue }
       if ($script:config.Files.Include) { $f = $f | ? FullName -like $script:config.Files.Include }
       if ($script:config.Files.Exclude) { $f = $f | ? FullName -notlike $script:config.Files.Exclude }

       if ($f.Count -eq 0) { Write-Warning "Empty migration: $migration"; continue }
       @{ migration = $migration; files = $f }
    }  
    $mf
}

function New-Handler( [string]$Name, $Connection ) {
    if ([string]::IsNullOrEmpty($Name)) { throw "Handler name can't be blank" }
    Write-Verbose "New handler instance: $Name"

    $handler_script = "$PSScriptRoot\handlers\$Name.ps1"
    if (!(Test-Path $handler_script )) { throw "Handler not found: $Name"}

    try { . $handler_script } catch { throw "Handler loading error: $_" }

    iex "[$Name]::new( `$Connection )"
} 

function log($msg, [switch] $Header, [switch] $NoNewLine ) {
    if ($Header) { $msg | Write-Host -ForegroundColor Blue; return }
    $msg | Write-Host
}


$script:module = $MyInvocation.MyCommand.ScriptBlock.Module
Export-ModuleMember -Function 'Invoke-Flow', 'New-Handler'