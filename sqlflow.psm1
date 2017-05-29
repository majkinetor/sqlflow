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
    
    get-MigrationFiles

    $csFirst = $config.Connections.Keys | select -First 1
    if (!$csFirst) { throw "No connection found" }
    $handler = New-Handler $config.Handler $config.Connections.$csFirst
    if ( $Reset ) {  Write-Warning "Reseting database"; $handler.RemoveDatabase() }

    ###############

    init_history $handler
    get-Changes $handler

    add_history $handler
    run-Files $handler
    update_history $handler
}

function set-Config([HashTable] $UserConfig) {
    $script:config = $UserConfig.Clone()
    if ( !$config.Directories) { $config.Directories = @('migrations') }
    if ( !$config.Migrations ) { $config.Migrations = { ls -Directory $config.Directories } }
}

function run-Files( $handler ) {

    $info.stats = [ordered]@{ Duration = 0; Migrations = 0; Files = 0; Errors = 0 }

    $migrations = $info.changes | group migration
    foreach ($m in $migrations) 
    { 
        $migration_errors = 0
        $start = Get-Date
        log -Header '',("Starting migration '{0}' - {1} files" -f $m.Name, $m.Count  )
        for ($i=1; $i -le $m.Count; $i++)
        {
            $file_path = $m.group[$i-1].Path         
            log ('{0}/{1} {2}' -f "$i".PadLeft(3), "$($m.Count)".PadRight(3), $file_path)
            $out, $err = $handler.RunFile( $file_path )
            if ($err.Count) { @("Errors: $($err.Count)") + $err | Write-Warning }
            $migration_errors += $err.Count
            $out
        }
        log -Header ( "Finished migration '{0}' after {1:f2} minutes - errors: {2}" -f $m.Name, ((Get-Date)-$start).TotalMinutes, $migration_errors)
        $info.stats.files  += $m.Count
        $info.stats.errors += $migration_errors
    }

    log -Header "`nSummary"
    $info.stats.migrations = $migrations.Count
    $info.stats.duration = ( (Get-Date) - $info.startDate ).TotalMinutes.ToString("#.##") + ' minutes'
    $info.stats.Keys | % { log "  $(${_}.PadRight(15)) $($info.stats.$_)"}
}

function get-MigrationFiles() {
    log "Setting up migrations"

    $migrations = . $config.Migrations | ? Name -ne 'sqlflow'
    $info.migrations = foreach ($migration in $migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$script:config.Files) { continue }
       if ($script:config.Files.Include) { $f = $f | ? Name -like $script:config.Files.Include }
       if ($script:config.Files.Exclude) { $f = $f | ? Name -notlike $script:config.Files.Exclude }

       $name  = Split-Path -Leaf $migration
       if ($f.Count -eq 0) { Write-Warning "Empty migration: $migration"; continue }
       $f | Get-FileHash -Algorithm MD5 | select @{ N='migration'; E={$name} }, Path, Hash
    } 
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

function update_history($Handler) {
    $out, $err = $Handler.RunSql(@"
        UPDATE $history_table
        SET Duration = '$($info.stats.duration)', 
            Result = 'todo'
        WHERE RunId = $($info.RunId)
"@)
    if ($err) {throw "Can't update history record: $err"}
}

function add_history ($Handler ) {
    function json($o) { ($o | ConvertTo-Json).Replace("'", "''") }
    function csv($o)  { ($o | ConvertTo-Csv -NoTypeInformation).Replace("'", "''") | Out-String }

    $out, $err = $Handler.RunSql(@"
INSERT INTO $history_table
    (RunId, StartDate, Config, Migrations, Changes)
VALUES( 
     $($info.RunId),                        -- RunId
    '$($info.startDate.ToString("s"))',     -- StartDate
    '$( json $config )',                    -- Config
    '$( csv $info.migrations)',             -- Migrations
    '$( csv $info.Changes)')                -- Changes
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
        $info.changes = $info.migrations
        return
    }

    log "  previous run (no. $($out.RunId)) was at $($out.StartDate) and took $($out.Duration)"
    $prev_migrations = $out.Migrations | ConvertFrom-Csv

    $info.RunId = 1 + $out.RunId
    $changes = Compare-Object -ReferenceObject $prev_migrations -DifferenceObject $info.migrations -Property Hash -PassThru
    if (!$changes) { log "  no changes found, aborting"; exit }
    $cc = $changes.Count
    log "  found $cc changes"

    $changes = $changes | ? { Test-Path $_.Path }
    if (!$changes) { log "  only deletions found, aborting"; exit }
    $cc2 = $changes.Count

    log "  new/updated: $cc2  deleted: $($cc -$cc2)"
    $info.changes = $changes
}

$module        = $MyInvocation.MyCommand.ScriptBlock.Module
$history_table = '_sqlflow_history'

Export-ModuleMember -Function 'Invoke-Flow', 'New-Handler'