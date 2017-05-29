#requires -version 5

$s = {
    chocolatey
    psgallery
    git_4windows

    pester
    
    # databases 
    #cinst sqlite
    #choco install sql-server-express #without full sqlserver: cinst sqlserver-cmdlineutils
}

function git_4windows() {
    if (!(gcm git -ea ignore)) { "Installing git"; cinst git }
    git --version
}

function pester() {
    "Installing pester"

    inmo pester -Force
    $version = gmo pester -ListAvailable | % { $_.Version.ToString() }
    "Pester version: $version"
}

function chocolatey() {
    "Installing chocolatey"

    iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
    "Chocolatey version: $(choco.exe -v)"
}

function psgallery() {
    "Installing PSGallery"

    Install-PackageProvider -Name NuGet -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

& $s
