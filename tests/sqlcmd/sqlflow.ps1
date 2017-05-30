param ([switch] $Reset )

$config = @{
    # DateFormat     = 's'
    Handler = 'sqlcmd'

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
        test  = @{ Username = 'test'; Password = 'test'; Database = 'test'   }
        admin = @{ Username = 'sa';   Password = 'test'; Database = 'master' }
    }
}

#$VerbosePreference = 'continue'

pushd $PSScriptRoot
import-module -force ..\..\sqlflow.psm1

$params = @{ FlowConfig = $config }
if ( $Reset ) { $params.Reset = $true }
Invoke-Flow @params