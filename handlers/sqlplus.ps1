function Invoke-SqlFile {
    param(
        # SQL file to invoke
        [System.IO.FileSystemInfo] $File,
        
        # Arguments to the script
        [string[]] $Arguments,
        
        # Connection object
        $Connection

    )

    $connString =  if ($AsAdmin) { $adminConnString } else { $userConnString }
    $out = "@$($File.FullName) $Arguments" | sqlplus $connString
    $out >> setup.log #Do not display this on screen only in log

    $errors = $out | Select-String  "SP2-","ORA-"
    $global:err_no += $errors.count
    if ($errors) { $OFS="`n"; Write-Verbose "$(@('ERRORS') + $errors)"  }
}