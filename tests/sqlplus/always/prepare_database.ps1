function prepare-database()
{
    "`n==| Preparing database"
    if ($Sid -eq "XE") { Import-SqlFile (gi src\extend_system_tablespace.sql) -AsAdmin }
    Import-SqlFile (gi src\kill_sessions_for_user.sql) -Arguments $User.ToUpper() -AsAdmin
}