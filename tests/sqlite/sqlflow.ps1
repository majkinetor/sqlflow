param ([switch] $Reset )

$config = @{
    DateFormat     = 's'
    Handler        = 'sqlite_shell'

    Directories = @(
        'migrations'
    )

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
        test = "test.db"
    }
}

#$VerbosePreference = 'continue'

pushd $PSScriptRoot
import-module -force ..\..\sqlflow.psm1

$params = @{ FlowConfig = $config }
if ( $Reset ) { $params.Reset = $true }
Invoke-Flow @params