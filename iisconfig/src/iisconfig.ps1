$ErrorActionPreference = 'Stop';

Import-Module WebAdministration

$currentDir = Split-Path $script:MyInvocation.MyCommand.Path
. $currentDir\apppool.ps1

function Create-Website (
    [Parameter(mandatory=$true)][string] $name,
    [Parameter(mandatory=$true)][int] $port,
    [Parameter(mandatory=$true)][string] $appPool,
    [Parameter(mandatory=$true)][string] $physicalPath,
    [string] $username,
    [string] $password,
    [bool] $deleteWebsite = $false) {

    Write-Host "Creating website '$name' with appPool '$appPool' on port '$port' and path '$physicalPath'"
    if($deleteWebsite) {
      Delete-Website $name
    }
    Create-AppPool -name $appPool -username $username -password $password
    
    New-Website `
      -Name $name `
      -Port $port  `
      -PhysicalPath $physicalPath `
      -ApplicationPool $appPool `
      -Force
}

function Delete-Website(
    [Parameter(mandatory=$true)]
    [string] $name) {

  $exists = (Get-Website -Name $name).Name -eq $name

  if($exists) {
    Write-Warning "Website '$name' already exists, deleting it"
    Remove-WebSite -Name $name
  } else {
    Write-Host "Website '$name' not found, nothing deleted"
  }
}



function Ensure-SiteExists([Parameter(mandatory=$true)][string] $siteName) {
  
  if((Get-Website -Name $siteName).Name -ne $siteName) {
    $message = "Failed to create web application '$name', website '$siteName' was not found"
    throw [System.InvalidOperationException] $message
  }
}
function Create-WebApplication (
    [Parameter(mandatory=$true)][string] $name,
    [Parameter(mandatory=$true)][string] $siteName,
    [Parameter(mandatory=$true)][string] $appPool,
    [Parameter(mandatory=$true)][string] $physicalPath,
    [string] $username,
    [string] $password,
    [bool] $isNetCore=$true) {
      
    Write-Host "Creating web application '$name' for website '$siteName' with app pool '$appPool' and path '$physicalPath'"

    $siteParts = $siteName.Split("/")
    if($siteParts.Length -gt 0) {
      Ensure-SiteExists $siteParts[0]
      $existingWebapp = "{0}/{1}" -f $siteParts[1], $name
      Delete-WebApplication $existingWebapp $siteParts[0]

    } else {
      Ensure-SiteExists $siteName
      Delete-WebApplication $name $siteName
    }
    
    if($isNetCore) {$runtimeVersion = "No Managed Code"} else {$runtimeVersion = "v4.0"}
    Create-AppPool -name $appPool `
      -username $username `
      -password $password `
      -runtimeVersion $runtimeVersion

    New-WebApplication `
      -Site $siteName `
      -Name $name `
      -PhysicalPath $physicalPath `
      -ApplicationPool $appPool `
      -Force
}

function Delete-WebApplication(  
  [Parameter(mandatory=$true)][string] $name,
  [Parameter(mandatory=$true)][string] $siteName) {

    if(Get-WebApplication -Name $name -Site $siteName) {
      Write-Warning "Web application '$name' already exists for website '$siteName', deleteing it"
      Remove-WebApplication -Name $name -Site $siteName
    }else {
      Write-Warning "Web application '$name' not found for website '$siteName', nothing deleted"
    }
}

function Create-WebVirtualDirectory (
    [Parameter(mandatory=$true)][string] $name,
    [Parameter(mandatory=$true)][string] $siteName,
    [Parameter(mandatory=$true)][string] $physicalPath) {

    Write-Host "Creating web vir dir '$name' for website '$siteName' with path '$physicalPath'"
    New-WebVirtualDirectory `
      -Site $siteName `
      -Name $name `
      -PhysicalPath $physicalPath `
      -Force
}

function Add-WebApplicationToWebSite( 
    [Parameter(mandatory=$true)][string] $siteName,
    [string] $sitePath,
    [Parameter(mandatory=$true)][string] $webappName,
    [Parameter(mandatory=$true)][string] $webappPath,
    [string] $webappUsername,
    [string] $webappPassword,
    [bool] $isNetCore = $true) {

  $appPoolName = $siteName.Replace(' ', '')
  if(![string]::IsNullOrEmpty($sitePath)) {  
    Create-Website -name $siteName -port 80 -appPool $appPoolName -physicalPath $sitePath
  } else {
    Write-Host "Skipped creating website '$siteName'"
  }

  $appPoolName = "{0}_{1}" -f $siteName.Replace(' ', ''), $webappName.Replace(' ', '')
  
  Create-WebApplication -name $webappName `
    -siteName $siteName `
    -appPool $appPoolName `
    -physicalPath $webappPath `
    -username $webappUsername `
    -password $webappPassword `
    -isNetCore $isNetCore
}

function Add-WebApplicationToVirtualDirectory(
    [Parameter(mandatory=$true)][string] $siteName,
    [string] $sitePath,
    [Parameter(mandatory=$true)][string] $virDirName,
    [string] $virDirPath,
    [Parameter(mandatory=$true)][string] $webappName,
    [Parameter(mandatory=$true)][string] $webappPath,
    [string] $webappUsername,
    [string] $webappPassword,
    [bool] $isNetCore=$true) {
  
  $appPoolName = $siteName.Replace(' ', '')
  if(![string]::IsNullOrEmpty($sitePath)) {  
    Create-Website -name $siteName -port 80 -appPool $appPoolName -physicalPath $sitePath
  } else {
    Write-Host "Skipped creating website '$siteName'"
  }

  if(![string]::IsNullOrEmpty($virDirPath)) {
    Create-WebVirtualDirectory -name $virDirName `
      -siteName $siteName `
      -physicalPath $virDirPath
  } else {
    Write-Host "Skipped creating virtual directory '$virDirName'"
  }

  $appPoolName = "{0}_{1}_{2}" -f `
    $siteName.Replace(' ', ''), 
    $virDirName.Replace(' ', ''), 
    $webappName.Replace(' ', '')
  
  Create-WebApplication -name $webappName `
    -siteName "$siteName/$virDirName" `
    -appPool $appPoolName `
    -physicalPath $webappPath `
    -username $webappUsername `
    -password $webappPassword `
    -isNetCore $isNetCore
}

function Get-AppPoolBySiteAppAndService([string] $siteName, [string] $appName, [string] $service) {
    $webAppName = $appName + "/$service"
    Write-Host "Looking up app pool by site" +  $siteName + "for $webAppName"
    return  (Get-WebApplication -Site $siteName -Name $webAppName ).ApplicationPool
}