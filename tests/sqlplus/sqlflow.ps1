param (
    [string] $Hostname      = 'localhost',
    [int]    $Port          = 1521,
    [string] $Sid           = 'XE',
    [string] $AdminUser     = 'sys',
    [string] $AdminPassword = '1234', 
    [string] $User          = 'test',
    [string] $Password      = 'test'
)

$config = @{
    # DateFormat     = 's'
    Handler = 'sqlplus'

    Directories = @(
        'migrations'
        'c:\Work\isib\Trezor\model\DDL'
        'c:\Work\isib\Trezor\model\DML'
        #'c:\Work\isib\Trezor\Pathces'
        #'c:\Work\isib\Trezor\source\TrezorMaster\TrezorPlsql\src\rs\saga\trezor\plsql'
        'c:\Work\isib\Trezor\model\COMPILE'
    )

    Files = @{
        Include  = '*.sql', '*.pls'
        Exclude  = '~*'
    }

    Migrations = {
          foreach ($dir_path in $config.Directories) 
          {
            if ((gi $dir_path).Name -ne 'Pathces') {  ls -Directory $dir_path; continue }
            ls $dir_path -Directory | % { [PSCustomObject]@{Dir = $_; Version = [version]($_.Name -replace 'patch_v_') }} | sort Version | % Dir 
          }
    }

    Connections = [ordered]@{
        user  = "$User/$Password@${Hostname}:$Port/$Sid"
        admin = "$AdminUser/$AdminPassword@${Hostname}:$Port/$Sid as Sysdba"
    }
}

#$VerbosePreference = 'continue'

pushd $PSScriptRoot
import-module -force ..\..\sqlflow.psm1

$params = @{ FlowConfig = $config }
if ( $Reset ) { $params.Reset = $true }
Invoke-Flow @params