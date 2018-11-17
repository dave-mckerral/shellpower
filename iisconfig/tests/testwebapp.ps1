param (
  [Parameter(mandatory=$true)][string] $packages
)

$ErrorActionPreference = "Stop"

. $packages/lib/webapp.ps1

function Setup-Website(
    [Parameter(mandatory=$true)][string] $username,
    [Parameter(mandatory=$true)][string] $password) {

    $root = "C:\inetpub"
    $shellpowerSite = "shellpower"
    $shellpowerApi = "api"
    
    $appPoolName = $shellpowerSite
    Create-AppPool -name $appPoolName
    Create-App -name $shellpowerSite -port 80 -appPool $appPoolName -physicalPath "$root\$shellpowerSite"
  
    $appPoolName = "{0}_{1}" -f $shellpowerSite, $shellpowerApi
    Create-AppPoolWithIdentity -name $appPoolName -username $username -password $password
    Create-VirtualApp -name $shellpowerApi -siteName $shellpowerSite -appPool $appPoolName -physicalPath "$root\$shellpowerApi"
}

function Test-WebsiteSetupCanBeRepeated {
    Setup-Website -username "sample-user" -password "apassword"
    Setup-Website -username "sample-user" -password "apassword"    
}

Test-WebsiteSetupCanBeRepeated