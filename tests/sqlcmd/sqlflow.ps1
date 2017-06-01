param ([string] $AdminPass = 'test', [string] $UserPass = 'test', [switch] $Reset )

$config = @{
    # DateFormat     = 's'
    Handler = 'sqlcmd_exe'

    # Directories = @(
    #     'migrations'
    # )

    Files = @{
        Include  = '*.sql'
        Exclude  = '~*'
        #Match
        #Notmatch
        #FullInclude
        #FullExclude
    }

    # Migrations = {
    #      ls -Directory $config.Directories
    # }

    Connections = [ordered]@{
        user  = @{ Username = 'test'; Password = $UserPass;  Database = 'test'   }
        admin = @{ Username = 'sa';   Password = $AdminPass; Database = 'master' }
    }
}

#$VerbosePreference = 'continue'

pushd $PSScriptRoot
import-module -force ..\..\sqlflow.psm1

$params = @{ FlowConfig = $config }
if ( $Reset ) { $params.Reset = $true }
Invoke-Flow @params