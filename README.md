# SQLM

Sql Migration Engine

## Concepts

- Executioners provide `Invoke-Sql` function that is used to execute sql and save execution results. They are located in the executioners folder. SQLM comes with default ones and user can implement its own.
```
function Invoke-SqlFile {
    param(
        # SQL file to invoke
        [System.IO.FileSystemInfo]$File,
        
        # SQL script arguments
        [string[]]$Arguments,
        
        # Connection string
        [string] $ConnectionString
    )
```

- Migrations directory keeps all the different migrations directories. Migration order is defined by the user function `Get-Migrations` which returns the list of directories that are executed by the given order. This is useful when sort order can't be achieved with file system, i.e. `[version]`, `[date]` etc.

```
    ISIB Migrations
        - migration name 1
        - migration name 2

        - 3.6.2017
        - 1.1.2015
```
- Directories - each migration contain of directories and all specified files are executes in those dirs. By default all sql files are included but user can specify both global or per-migration include/exclude.

```
    ISIB Migrations
        - 0.0.1
            - MyFolder1
            - MyFolder2
```
- Scrips - each migration contains PowerShell scripts that can be executed. Besides that, there are global scripts
```
    Executioners
        SqlPlus
    Scripts
        BeforeMigration
        AfterMigration
        Before
        After   
            Seed.ps1 - #Cherry pick some additional files, for example execute sql files in the `Seed` folder at the end from each migration.
        OnFile
            Preprocess.ps1    - For example add ECHO ON on the start and ECHO OFF at the end.
            Set-Encoding.ps1  - Set correct sql file encoding.
    Migrations
        - 0.0.1
            - SQL\MyFolder1
            - SQL\MyFolder2
            - Seed
            - Scripts
                - BeforeMigration.ps1
                - AfterMigration.ps1
                - BeforeMigrationOnce.ps1
                - AfterMigrationOnce.ps1
                - script1.ps1
                - script2.ps1
```
- Everything has default, or can be overriden.
- Internnaly Posh5+ classes
- Gather all files for preprocessing - SAGA plsql case that ignores migrative plsqls on specific migrations. 
- Migration table lists each file and complete setup
- Hooks for OnFile (used for preprocessing of a file, can return different path or cancel it) and OnFiles (gets the list of all files to be executed in that run and can filter out specific ones or add new ones).
- Migration.ps1 script with functions like AU perhaps. Perhaps functions instead of scripts (since functions can include scripts).
- Perpetual folders - Saga plsql case. They do not really fit into migration history per se, history would have to include effective runs rather then list of migration names (option - allow perpetual).
- Prvih nekoliko redova moze da sadrzi 'sqlflow' komentar
    -- sqlflow: exclude; connection: admin; runer: sqlite_shell 

---

# Facts 

- Sqloflow is driven by HashTable configuration with most options
- Migration is a directory, set of migrations is ordered list of directories. List of migrations is found by looking at the subdirectories contained in the $config.Directories. There is one special migration 'sqlflow' that can be specified in any directory. If not specified defaults to 'migrations' directory in current folder of sqlflow.ps1 configuration.
- Connections is a ordered list of named HashTables. First connection is the default one which is used if connection isn't specified some other way (file or directory options). The default connection is also used to manage history table. Connections use Handlers that implement various types of databases. The Handler can be specified in each connection or can be omitted in which case $config.Handler is used as a default one (to be used if all connections use the same handler). Multiple handlers can be used for some weird cases. Connection can also be a string in which case its converted to `@{ Database = 'string' }` hashtable as this can be enough to establish a connection in some cases (sqlite, local host with trusted settings as default, using defaults for username/pass etc. )
- File options are specified inside SQL comment on the first line of the sql file.