#Requires –Version 4
# Author: Miodrag Milic <miodrag.milic@trezor.gov.rs>
# Last Change: 22-Nov-2016.

[CmdletBinding(DefaultParameterSetName='Action')]
param (
    [String] $Hostname            = "localhost",
    [String] $Port                = "1521",
    [String] $Sid                 = "XE",
    [String] $AdminUser           = "sys",
    [String] $AdminPassword       = "1234",
    [String] $User                = "test",
    [String] $Password            = "test",

    #Execute given action
    [Parameter(ParameterSetName="Action")]
    [ValidateSet("Everything", "User", "DDL", "DML", "PLSQL", "COMPILE", "PATCHES")]
    [String] $Action="Everything",

    #Do not check file changes from previous run
    [Parameter(ParameterSetName="Action")]
    [switch] $NoCheck,

    [Parameter(ParameterSetName="Patch")]
    #Install only specified patch, by default the last one.
    [string] $Patch,

    [Parameter(ParameterSetName="Files")]
    #Execute files via glob specification.
    [string] $FilesGlob,

    #Special parameter that servers to execute Everything up to the given Patch only.
    #This means that PLSQL from all patches will get executed and PLSQL at the end wont.
    #This is opposite from what happens when it is not specified.
    [Parameter(ParameterSetName="Action")]
    [string] $EndPatch
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8 #Must be set so that cyrillic chars are visible in the log

pushd $PSScriptRoot
$ENV:NLS_LANG               = ".UTF8"           #Must be set to see cyrilic without garbage
$ENV:NLS_LENGTH_SEMANTICS   = "CHAR"            #Must be set due to cyrilic chars, otherwise 'value too large for column' error appears

$global:root            = gi ..\..\..           #root of the repository
$global:include         = "*.sql", "*.pls"      #List of file globs to look at
$global:exclude         = "~*"                  #List of file globs to exclude
$global:userConnString  = "$User/$Password@${Hostname}:$Port/$Sid"
$global:adminConnString = "$AdminUser/$AdminPassword@${Hostname}:$Port/$Sid as Sysdba"
$global:NoCheck         = $NoCheck              #mhm... can't get the scope right with this one...

$global:prev_files_path = "$PSScriptRoot\.prev_files.xml" #holds checksums of files executed in the previous run

# @{ Name, Path, AppendSql, Options=[nodrop]}
# function get-files determines the file order within the directories
$Dirs=@(
    @{ Name="DDL";    Path="$root\model\DDL" }
    @{ Name="DML";    Path="$root\model\DML" }
    @{ Name="Patches";Path="$root\Pathces";}   #WARNING: This folder cant use AppendSql='/' because it combines DDL, DML and PLSQL while AppendSql should only be applied to PLSQL
    @{ Name="PLSQL";  Path="$root\source\TrezorMaster\TrezorPlsql";  AppendSql = "/";  Options = "nodrop"}
    @{ Name="COMPILE";Path="$root\model\COMPILE" }
)
function get-files ($Dir, $Include=$global:include, $Exclude=$global:exclude ) {
    ls $Dir -Recurse -Include $Include -Exclude $Exclude
}

function main() {
    if (!( gcm sqlplus -ea 0)) { throw "sqlplus not found on the PATH. Oracle Database XE 11g is required. " }
    rm setup.log -ea 0

    $sw = [Diagnostics.Stopwatch]::StartNew()
    log ("Setup started at {0} by {1}" -f (get-date).ToString('s'), "$ENV:USERDOMAIN\$Env:USERNAME")

    $global:err_no  = 0
    $global:file_no = 0

    if ($PsCmdlet.ParameterSetName -eq 'Patch') { execute-patch; show-stats; return }
    if ($PsCmdlet.ParameterSetName -eq 'Files') { execute-files; show-stats; return }

    test-changes            #exits the script if no changes are required

    prepare-database
    if ($global:NoCheck -or $do_drop -or ($Action -ne 'Everything') ) {
        recreate-user       #creates user only if $Action -eq 'User', otherwise it returns ASAP
        execute-dirs
    }
    else { execute-diff }

    $global:cur_files | export-clixml $global:prev_files_path

    show-stats
}

function execute-files() {
    log "`n==| Executing files`n"
    $files = ls $FilesGlob -ea STOP

    log "Glob specification: $FilesGlob" 2
    log "File count: $($files.Count)" 2
    log ""

    $files | % { Import-SqlFile $_ -PrependSql "SET ECHO ON" }
}

function execute-patchdir($PatchDir) {
    <#
     Patch dirs are special:
       They can't use AppendSql='/' because it combines DDL, DML and PLSQL while AppendSql should only be applied to PLSQL files.
       For that reason, the files are split and AppendSql='/' is forced on PLSQL dirs in Patches.
    #>

    get-files $PatchDir | ? { $_.FullName -notmatch "\\plsql\\" } | % { Import-SqlFile $_ -PrependSql "SET ECHO ON" }
    get-files $PatchDir | ? { $_.FullName -match    "\\plsql\\" } | % { Import-SqlFile $_ -PrependSql "SET ECHO ON" -AppendSql '/' }
}

function execute-patch()  {
    log "`n==| Patch information`n"

    $patches_dir = $Dirs | ? Name -eq 'Patches' | % Path
    log "Root directory: $patches_dir" 2

    $versions =  ls $patches_dir | % Name | % { $_ -split '_' | select -Last 1 | % { [version]$_ } }
    $last = $versions | measure -Maximum | % Maximum | % { $_.ToString() }

    if ($Patch) {
        $patch_dir = gi "$patches_dir\*$Patch*"
        if (!$patch_dir) { throw "Patch '$Patch' not found" }
    } else {
        $patch_dir = gi "$patches_dir\*$last*"
        $Patch = $last
    }
    log "Patch: $Patch" 2

    log "`n==| Executing directory: $patch_dir"
    execute-patchdir $patch_dir
}

function test-changes() {

    function compare-files() {
        log "==| Compare files with those from previous run"

        $prev_files = import-clixml $global:prev_files_path
        $c = Compare-Object -ReferenceObject $prev_files -DifferenceObject $global:cur_files -Property Hash
        if (!$c) { log "No difference found, aborting" 2; exit }

        $diff = $c.InputObject
        $global:new_files     = $global:cur_files | ? { $prev_files.Hash -notcontains $_.hash }
        $global:deleted_files = $prev_files | ? { $global:cur_files.Path -notcontains $_.Path }
        $global:diff_files    = @($new_files) + @($deleted_files)

        if ($new_files)     { log "New or changed files" 2;  $new_files | % { log $_.Path 3} }
        if ($deleted_files) { log "Deleted files" 2;     $deleted_files | % { log $_.Path 3} }
    }

    function inspect-files() {
        log "==| Inspect files"
        foreach ($f in $global:diff_files) {
            $dir = get-filedir $f
            $global:do_drop = $dir.Options -notlike '*nodrop*'
            if ($global:do_drop) { log "About to drop schema due to the changes in the '$($dir.Name)'" 2; break }
        }

        if (!$global:do_drop) { log "There seems to be no need to drop the schema" 2 }
    }

    $files = @()
    $Dirs | % { $files += get-files $_.Path }

    log "==| Calculating file cheksums"
    $global:cur_files = $files | Get-FileHash -Algorithm MD5

    if (!(Test-Path $global:prev_files_path))  { $global:NoCheck = $true }
    if (!$global:NoCheck) {
        compare-files
        inspect-files
    }
}

function get-filedir($f) { $dirs | ? { $f.Path -like "$($_.Path)*" } }

function execute-diff() {
    log "`n==| Executing diff"
    log "Doing nothing about $(@($global:deleted_files).Length) deleted files" 2

    $global:new_files | % {
        $dir = get-filedir $_
        Import-SqlFile (gi $_.Path) -PrependSql "SET ECHO ON" -AppendSql $dir.AppendSql
    }
}

function execute-dirs() {
    foreach ($dir in $Dirs)  {
        if ( ("Everything", $dir.Name) -notcontains $Action ) {  Write-Verbose "Skipping directory: $($dir.Name)"; continue }

        log "`n==| Executing directory: $($dir.Name)"
        $files = get-files $dir.path

        #Special cases are handled here
        switch( $dir.Name ) {
            'PLSQL'   { if ($EndPatch) { Write-Verbose 'Skipping directory PLSQL because of the EndPatch'; continue } }

            'Patches' {
                $patches = ls "$($dir.path)\patch_v_*" | % { [PSCustomObject]@{Dir = $_; Version = [version]($_.Name -replace 'patch_v_') }} | sort Version

                if ($EndPatch) {
                    foreach ($patch in $patches) {
                        if ( $patch.Version -gt ([version]$EndPatch) ) { Write-Verbose "Skipped newer patches"; break }
                        execute-patchdir $patch.Dir
                    }
                    continue
                }
                else {
                    # Dir "PLSQL" uvek ima najnovije verzije SQLova, tako da u ne-patch modu treba ignorisati plsql fajlove u dir. Patches
                    log "NOTE: ignoring PLSQL files in Patches in this mode" 2
                    $files = $patches | % { get-files $_.Dir } | ? { $_.FullName -notmatch "\\plsql\\" }
                }
            }
        }

        $files | % { Import-SqlFile $_ -PrependSql "SET ECHO ON" -AppendSql $dir.AppendSql }
    }
}

function Import-SqlFile {
    param(
        # SQL file to import
        [System.IO.FileSystemInfo]$File,
        # Arguments to the script
        [string[]]$Arguments,
        # SQL lines to prepend to the file content
        [String[]]$PrependSql=$null,
        # SQL lines to append to the line content
        [String[]]$AppendSql=$null,
        # Set to import sql file using admin credentials
        [switch] $AsAdmin
    )

    log "$File" 2

    $global:file_no += 1
    $tmpFileName = "$Env:Temp\$($File.Name)"
    $sqlContent = Get-Content $File -Encoding UTF8
    [System.IO.File]::WriteAllLines($tmpFileName, $PrependSql + $sqlContent + $AppendSql) #sqlplus doesn't like BOM (http://goo.gl/UytAUd)

    $connString =  if ($AsAdmin) { $adminConnString } else { $userConnString }
    $out = "@$tmpFileName $Arguments" | sqlplus $connString
    $out >> setup.log #Do not display this on screen only in log

    $errors = $out | Select-String  "SP2-","ORA-"
    $global:err_no += $errors.count
    if ($errors) { $OFS="`n"; Write-Verbose "$(@('ERRORS') + $errors)"  }
}

function log ( $Msg, $Pad = 0 ) {
    if ($Pad) { $Msg = ' '*$Pad*2 + $Msg }
    $Msg | tee -Append setup.log
}

function prepare-database()
{
    "`n==| Preparing database"
    if ($Sid -eq "XE") { Import-SqlFile (gi src\extend_system_tablespace.sql) -AsAdmin }
    Import-SqlFile (gi src\kill_sessions_for_user.sql) -Arguments $User.ToUpper() -AsAdmin
}

function recreate-user() {
    if ( ("Everything","User") -notcontains $Action ) { Write-Verbose "Skipping User creation"; return }

    log "`n==| Recreating user '${User}'"
    $out = "DROP USER ${User} CASCADE;" | sqlplus $adminConnString
    if (($out -match "ORA-") -and (($out -join '') -notmatch "ORA-01918")) { throw $($out | sls "ORA-")}

    Import-SqlFile (gi src\create_user.sql) -AsAdmin -Arguments $User,$Password
}


function show-stats() {
    log "`n==| Summary`n"
    $log = gc setup.log
    log "Objects Created:" 1
    "Table", "Index", "Sequence", "Procedure", "Function" | % {
        $count = ($log | sls "$_ created").count
        log "$_ : $count" 2
    }
    log ""
    log "Total Errors: $global:err_no" 2
    log "Total Files: $global:file_no" 2
    log ""
    log ("Trajanje u minutima: " + ("{0:f2}" -f ($sw.ElapsedMilliseconds/60000)))
    "`nOutput saved in the SETUP.LOG file`n"
}

main
popd
trap { popd }
