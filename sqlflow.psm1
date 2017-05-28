function Invoke-Flow {
    param(
        # Sqlflow migration config
        [HashTable]$FlowConfig, 

        # Remove database before start to apply all migrations
        [switch] $Reset 
    )

    set-Config $FlowConfig
    $script:info = @{}
    
    $info.startDate = Get-Date
    log ( "Started {0} version {1}`n  at {2}`n  by {3}`n" -f $module.Name, $module.Version, $info.startDate.ToString($config.DateFormat), "$Env:USERDOMAIN\$Env:USERNAME@$Env:COMPUTERNAME" )
    
    $migrations = . $Config.Migrations | ? Name -ne 'sqlflow'
    $info.migrations  = get-MigrationFiles $migrations 

    $csFirst = $config.Connections.Keys | select -First 1
    if (!$csFirst) { throw "No connection found" }
    $handler = New-Handler $config.Handler $config.Connections.$csFirst
    if ( $Reset ) {  Write-Warning "Reseting database"; $handler.RemoveDatabase() }

    ###############

    init_history $handler
    get-Changes $handler
    run-Files $handler
}

function set-Config([HashTable] $UserConfig) {
    $script:config = $UserConfig.Clone()
    if ( !$config.Directories) { $config.Directories = @('migrations') }
    if ( !$config.Migrations ) { $config.Migrations = { ls -Directory $config.Directories } }
}

function run-Files( $handler ) {
    $stats = [ordered]@{ Time = 0; Migrations = 0; Files = 0; Errors = 0 }
    foreach ($m in $info.migrations) 
    { 
        $fcount = $m.files.Count
        $migration_errors = 0
        $start = Get-Date
        log -Header '',("Starting migration '{0}' - {1} files" -f $m.Name, $fcount  )
        for ($i=1; $i -le $fcount; $i++)
        {
            $file_path = $m.files[$i-1].Path         
            log ('{0}/{1} {2}' -f "$i".PadLeft(3), "$fcount".PadRight(3), $file_path)
            $out, $err = $handler.RunFile( $file_path )
            if ($err.Count) { @("Errors: $($err.Count)") + $err | Write-Warning }
            $migration_errors += $err.Count
            $out
        }
        log -Header ( "Finished migration '{0}' after {1:f2} minutes - errors: {2}" -f $m.Name, ((Get-Date)-$start).TotalMinutes, $migration_errors)
        $stats.files  += $fcount
        $stats.errors += $migration_errors
    }

    log -Header "`nSummary"
    $stats.migrations = $info.migrations.Count
    $stats.time = ( (Get-Date) - $info.startDate ).TotalMinutes.ToString("#.##") + ' minutes'
    $stats.Keys | % { log "  $(${_}.PadRight(15)) $($stats.$_)"}
}

function get-MigrationFiles( $Migrations ) {
    log "Setting up migrations"

    $mf = foreach ($migration in $Migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$script:config.Files) { continue }
       if ($script:config.Files.Include) { $f = $f | ? FullName -like $script:config.Files.Include }
       if ($script:config.Files.Exclude) { $f = $f | ? FullName -notlike $script:config.Files.Exclude }

       if ($f.Count -eq 0) { Write-Warning "Empty migration: $migration"; continue }
       @{ 
           name  = Split-Path -Leaf $migration
           files = $f | Get-FileHash -Algorithm MD5 | select Path, Hash
        }
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

function init_history($Handler) {
    if ( $Handler.TableExists( $script:history_table ) ) { return }

    Write-Warning "History table doesn't exist, creating it"
    $_, $err = $Handler.RunFile('migrations\sqlflow\_sqlflow_history.sql')
    if ( $err ) { throw "Error creating history table: $err" }
}

function add_history ($Handler, $EndDate='NULL', $Changes='NULL', $Result='NULL') {
    function q($s) { $s.Replace("'", "''") }

    $out, $err = $Handler.RunSql(@"
INSERT INTO $history_table
(RunId, StartDate, EndDate, Config, Migrations, Changes, Result)
VALUES(
    $($info.RunId),                                 -- RunId
    '$($info.startDate.ToString("s"))',             -- StartDate
    $EndDate,                                       -- EndDate
    '$( q ($config | ConvertTo-Json) )',            -- Config
    '$( q ($info.migrations | ConvertTo-Json))',    -- Migrations
    '$Changes',                                     -- Changes
    '$( q $Result)')                                 -- Result
"@)
    if ($err) {throw "Can't get history record: $err"}
}

function get-Changes( $Handle ) {

    log "Getting history"
    $out, $err = $Handler.RunSql( ('select * from {0} where RunId = (select max(RunId) from {0})' -f $history_table) )
    if ($err) {throw "Can't get history record: $err"}
    if (!$out) { 
        $info.RunId = 1
        log "No history found, all migrations will be applied"
        add_history $Handler -Hashes $hashes
    }
}

$module        = $MyInvocation.MyCommand.ScriptBlock.Module
$history_table = '_sqlflow_history'

Export-ModuleMember -Function 'Invoke-Flow', 'New-Handler'