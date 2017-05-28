$config = @{
    DateFormat     = 's'
    Handler        = 'sqlite_shell'

    Directories = @(
        'migrations'
    )

    Files = @{
        Include  = '*.sql'
        Exclude  = '~*'
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
Invoke-Flow -FlowConfig $config -Reset