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

    init_connections
    init_database
    # if ( $Reset ) {  Write-Warning "Reseting database"; $handler.RemoveDatabase() }

    get-Changes

    add_history
    run-Files
    update_history
}

function Invoke-SqlFile( [string] $SqlFilePath, [switch]$Throw ) {
    function get-opts() {
        $l = gc $SqlFilePath | select -First 1
        
        $opts=@{} 
        $re_opt_marker = '^\s*--\s*\|sqlflow\|'
        if ($l -match $re_opt_marker) { 
            $l = $l -replace $re_opt_marker
            $l -split ';' | % { $a = $_ -split ':'; $opts[ $a[0].Trim() ] = $a[1].Trim() } 
        }

        if (!$opts.connection) { 
            $opts.connection = $info.connections.Keys | select -First 1
        } else {
            if (! $info.connections.Contains( $opts.connection )) { throw "Connection '$($opts.connection)' not found: $SqlFilePath" }    
        }
        $opts
    }

    $file_opts = get-opts
    $conn = $info.connections[ $file_opts.connection ]
    $conn.RunFile( $SqlFilePath )
}

function init_database() 
{
    Invoke-SqlFile (Join-Path $info.sqlflow_migration.FullName 'init_database.sql') -Throw
    Invoke-SqlFile (Join-Path $info.sqlflow_migration.FullName 'init_history.sql')  -Throw
}

function init_connections() {
    if ($config.Connections -isnot [System.Collections.Specialized.OrderedDictionary]) { throw "'Connections' must be ordered HashTable" }
    if (!$config.Connections.Count) { throw 'At least one connection must be specified' }

    $info.connections = [ordered]@{}
    foreach ($k in $config.Connections.Keys) 
    {
        $c = $config.Connections.$k
        if ( $c -is [string] ) { $c = @{ Database = $c} }
        if ( $c -isnot [hashtable] ) { throw 'Connection must be of type Hashtable or string' }
        if ( !$c.Handler ) { $c.Handler = $config.Handler }

        $info.connections.$k = New-Connection $c
    }

    $info.defcon = $info.connections[ ($info.connections.Keys | select -First 1) ]  
}

function set-Config([HashTable] $UserConfig) {
    $script:config = $UserConfig.Clone()
    if ( !$config.Directories)      { $config.Directories = @('migrations') }
    if ( !$config.Migrations )      { $config.Migrations = { ls -Directory $config.Directories } }
    if ( !$config.Files)            { $config.Files = @{ Include = '*.sql'} }
    if ( !$config.Files.Include )   { $config.Files.Include = '*.sql' }
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
            $out, $err = Invoke-SqlFile $file_path
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
    $info.stats.duration = ( (Get-Date) - $info.startDate ).TotalMinutes
    $info.stats.Keys | % { log "  $(${_}.PadRight(15)) $($info.stats.$_)"}
}

function get-MigrationFiles() {
    log "Getting all available migrations"

    $migrations = . $config.Migrations
    $info.sqlflow_migration = $migrations | ? Name -eq 'sqlflow'

    $migrations = $migrations | ? Name -ne 'sqlflow'
    $info.migrations = foreach ($migration in $migrations) { 
       $f = $migration | ls -File -Recurse 
       if (!$script:config.Files) { continue }
       if ($script:config.Files.Include) { $f = $f | ? Name -like $script:config.Files.Include }
       if ($script:config.Files.Exclude) { $f = $f | ? Name -notlike $script:config.Files.Exclude }

       $name  = Split-Path -Leaf $migration
       if ($f.Count -eq 0) { Write-Warning "Empty migration: $migration"; continue }
       $f | Get-FileHash -Algorithm MD5 | select @{ N='migration'; E={$name} }, Path, Hash
    } 

    if ( !$info.migrations ) {throw 'No migration found'}
}

function New-Connection( $Connection ) {
    $handler = $Connection.Handler
    if ([string]::IsNullOrEmpty($handler)) { throw "Handler must be specified" }
    Write-Verbose "New connection instance: $handler"

    $handler_script = "$PSScriptRoot\handlers\$handler.ps1"
    if (!(Test-Path $handler_script )) { throw "Handler not found: $handler"}

    try { . $handler_script } catch { throw "Handler loading error: $_" }

    iex "[$handler]::new( `$Connection )"
} 

function log($msg, [switch] $Header, [switch] $NoNewLine ) {
    if ($Header) { $msg | Write-Host -ForegroundColor Blue; return }
    $msg | Write-Host
}

function update_history($Handler) {
     $info.defcon.RunSql("
        UPDATE $history_table
        SET Duration = '$($info.stats.duration)', 
            Result   = 'todo'
        WHERE RunId = $($info.RunId)
    ")
}

function add_history ($Handler ) {
    function bjson($o) { base64 ($o | ConvertTo-Json) -Encode }

    $iso_date = $info.startDate.ToString("O") -replace '\.\d+'
    $info.defcon.RunSql("
        INSERT INTO $history_table
                (RunId, StartDate, Migrations, Changes, Result)
        VALUES( $($info.RunId), '$iso_date', '$( bjson $info.migrations)', '$( bjson $info.Changes)', NULL )
    ")
}

function get-Changes( $Handle ) {

    function get_migration_row($string_row) {
        $out = @{}
        $history_cols = 'RunId', 'StartDate', 'Duration', 'Migrations', 'Changes', 'Result'
        $string_row.Split(' ') | % {$i=0} { $out[ $history_cols[$i++] ] = $_ }
        if ($history_cols.Count -ne $out.Count) {throw "$($info.history_table) - wrong number of columns"}
        
        $out.StartDate  = [datetime]::Parse($out.StartDate)
        $out.Migrations = base64 $out.Migrations -Decode | ConvertFrom-Json
        $out.Changes    = base64 $out.Changes -Decode | ConvertFrom-Json 
        $out.Result     = base64 $out.Result -Decode

        $out
    }

    log "Getting history"
    $res = $info.defcon.RunSql( ('select * from {0} where RunId = (select max(RunId) from {0})' -f $history_table) )
    if (!$res) { 
        $info.RunId = 1
        log "No history found, all migrations will be applied"
        $info.changes = $info.migrations
        return
    }

    $out = get_migration_row $res

    log "  previous run (no. $($out.RunId)) was at $($out.StartDate) and lasted $($out.Duration)"
    $prev_migrations = $out.Migrations

    $info.RunId = 1 + $out.RunId
    $changes = Compare-Object -ReferenceObject $prev_migrations -DifferenceObject $info.migrations -Property Hash -PassThru
    $deletes = $changes | ? SideIndicator -eq '<=' | ? { !(Test-Path $_.Path)} | select * -Exclude SideIndicator
    $changes = $changes | ? SideIndicator -eq '=>' | select * -Exclude SideIndicator
    
    $dc = $deletes | measure | % Count
    $cc = $changes | measure | % Count

    if ($deletes -and !$changes) { log "  only $dc deletions found, aborting"; exit } 
    if (!$changes) { log "  no changes found, aborting"; exit }

    $cc2 = $changes | measure | % Count

    log "  changes: $($cc+$dc);  new/updated: $cc;  deleted: $dc"
    $info.changes = $changes
}

function base64([string] $String, [switch] $Encode, [switch] $Decode ) {
    if ($Encode) { [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes($String) )   }
    if ($Decode) { [System.Text.Encoding]::UTF8.GetString( [System.Convert]::FromBase64String($String)) }
}

$module        = $MyInvocation.MyCommand.ScriptBlock.Module
$history_table = '_sqlflow_history'

Export-ModuleMember -Function 'Invoke-Flow', 'New-Connection', 'Invoke-SqlFile'