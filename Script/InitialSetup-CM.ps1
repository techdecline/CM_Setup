#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '30.10.2016 19:48:14'.

# Uncomment the line below if running in an environment where script signing is
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Helper Functions
###########

function Add-NewACE
{
	# FÃƒÂ¼gt einem Objekt eine gewÃƒÂ¼nschte ACE hinzu
	param (
		[System.IO.DirectoryInfo]$DirectoryItem,
		[String]$User,
		[System.Security.AccessControl.FileSystemRights]$AccessRule
	)

	$aclObj = Get-Acl $DirectoryItem
	$userpermissions = New-Object System.Security.AccessControl.FileSystemAccessRule($User,$AccessRule, [System.Security.AccessControl.InheritanceFlags]::None, [System.Security.AccessControl.PropagationFlags]::None, "Allow")
	$aclObj.AddAccessRule($userpermissions) | Out-Null
	Set-Acl $DirectoryItem $aclObj
}

# Global Variables
##################

$siteCode = "DEC"
$siteCodeConnect = $siteCode + ":"
$siteServerFqdn = "CM-Server1.decline.lab"
$sqlServerFqdn = "CM-Server1.decline.lab"
$modulePath = 'D:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1'
$boundaryGroupName = "bg-DEC"
$bootImageName = "DECLINE Boot Image (x64)"
$pxePassword = (ConvertTo-SecureString -AsPlainText 'Passw0rd' -Force)
$distributionPointGroup = "dpg-DEC"
$wsusParameterSet = " postinstall SQL_INSTANCE_NAME=$sqlServerFqdn\SCCM CONTENT_DIR=E:\WSUS"
$supDir = "E:\SUP"
$orgaName = "DECLINE Lab"

## Active Directory
$sysDiscoveryLocation = @("ldap://OU=Servers,DC=decline,DC=lab","ldap://OU=Workstations,DC=decline,DC=lab")
$userDiscoveryLocation = @("ldap://CN=Users,DC=decline,DC=lab")
$groupDiscoveryLocation = @("ldap://CN=Users,DC=decline,DC=lab")

## Service Accounts
$svcAccHash = @(
    @{
        AccountName = "decline\cm-push"
        Password = ConvertTo-SecureString -AsPlainText "Passw0rd" -Force
        Role = "PushAccount"
    },
    @{
        AccountName = "decline\cm-naa"
        Password = ConvertTo-SecureString -AsPlainText "Passw0rd" -Force
        Role = "NetworkAccessAccount"
    },
    @{
        AccountName = "decline\cm-rsp"
        Password = ConvertTo-SecureString -AsPlainText "Passw0rd" -Force
        Role = "ReportingServicesAccount"
    }
)


# Load Module and connect ConfigMgr
###################################

Import-Module  $modulePath # Import the ConfigurationManager.psd1 module
Set-Location $siteCodeConnect # Set the current location to be the site code.


# Setup Discovery Methods
# #######################

# Setup System Discovery
Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery -Enabled $true -SiteCode $siteCode -EnableDeltaDiscovery $true `
    -AddActiveDirectoryContainer $sysDiscoveryLocation -Recursive

# Setup Forest Discovery
Set-CMDiscoveryMethod -ActiveDirectoryForestDiscovery -SiteCode $siteCode -Enabled $true -EnableActiveDirectorySiteBoundaryCreation $true `
    -EnableSubnetBoundaryCreation $true

# Setup Group Discovery
foreach ($ou in $groupDiscoveryLocation)
{
    $scope = New-CMADGroupDiscoveryScope -LdapLocation $ou -Name "OU_$ou" -RecursiveSearch $true
    Set-CMDiscoveryMethod -ActiveDirectoryGroupDiscovery -Enabled $true -SiteCode $siteCode -EnableDeltaDiscovery $true `
        -AddGroupDiscoveryScope $scope
}

# Setup User Discovery
Set-CMDiscoveryMethod -ActiveDirectoryUserDiscovery -Enabled $true -SiteCode $siteCode -EnableDeltaDiscovery $true `
    -IncludeGroups -Recursive -AddActiveDirectoryContainer $userDiscoveryLocation

# Setup Service Accounts
########################

# Setup Network Access Account
New-CMAccount -UserName $svcAccHash.Where({$_.Role -eq "NetworkAccessAccount"}).AccountName -Password $svcAccHash.Where({$_.Role -eq "NetworkAccessAccount"}).Password -SiteCode $siteCode
Set-CMSoftwareDistributionComponent -SiteCode $siteCode -NetworkAccessAccountName $svcAccHash.Where({$_.Role -eq "NetworkAccessAccount"}).AccountName -Verbose

# Setup CM Client Push Account
New-CMAccount -UserName $svcAccHash.Where({$_.Role -eq "PushAccount"}).AccountName -Password $svcAccHash.Where({$_.Role -eq "PushAccount"}).Password -SiteCode $siteCode


# Setup Fallback Status Point
#############################

# Add Site System Role
Add-CMFallbackStatusPoint -SiteSystemServerName $siteServerFqdn -SiteCode $siteCode

# Enable Usage of Fallback Site
Set-CMHierarchySetting -FallbackSiteCode $siteCode -Verbose -UseFallbackSite $true
## Does not work, will be setup manually


# Setup PXE on DP
#################

# Prepare directories
New-Item "E:\Sources\OSD" -ItemType Directory
New-Item "E:\Sources\OSD\Boot Images" -ItemType Directory
New-Item "E:\Sources\OSD\Boot Images\x64" -ItemType Directory

# Copy Default Boot Image
$oldPath = "D:\Program Files\Microsoft Configuration Manager\OSD\boot\x64\boot.wim"
Copy-Item $oldPath "E:\Sources\OSD\Boot Images\x64" -Force

# Create new Boot Image
$newImage = New-CMBootImage -Path "\\$siteServerFqdn\Sources\OSD\Boot Images\x64\boot.wim" -Index 1 -Name $bootImageName

# Customize Image
Set-CMBootImage -Name $bootImageName -Version $newImage.ImageOsVersion -EnableCommandSupport $true `
    -DeployFromPxeDistributionPoint $true

# Disable PXE for default x64 image
Set-CMBootImage -Name "Boot Image (x64)" -DeployFromPxeDistributionPoint $false


# Install PXE Support on DP
Get-CMDistributionPoint | Set-CMDistributionPoint -EnablePxe $true -AllowPxeResponse $true `
    -EnableUnknownComputerSupport $true -PxePassword $pxePassword `
    -ClearMacAddressForRespondingPxeRequest
# returns immediately, installation started, check distmgr.log


Start-Sleep -Seconds 300

# Tuning TFTP Needs thorough testing before rolling out in production
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\SMS\DP -Name RamDiskTFTPWindowSize -Value 4 -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\SMS\DP -Name RamDiskTFTPBlockSize -Value 4096 -Force
Restart-Service WDSServer


# Run Forest Discovery needs further testing
Invoke-CMForestDiscovery -SiteCode $siteCode -Verbose
Start-Sleep -Seconds 300

# Setup Boundary Group
New-CMBoundaryGroup -Name $boundaryGroupName -DefaultSiteCode $siteCode
Set-CMDistributionPoint -AddBoundaryGroupName $boundaryGroupName -SiteSystemServerName $siteServerFqdn
Get-CMBoundary | Add-CMBoundaryToGroup -BoundaryGroupName $boundaryGroupName

# Setup Distribution Point Group
New-CMDistributionPointGroup -Name $distributionPointGroup
Add-CMDistributionPointToGroup -DistributionPointName $siteServerFqdn -DistributionPointGroupName $distributionPointGroup

# Distribute Boot Images to DP
Start-CMContentDistribution -BootImageName $bootImageName -DistributionPointGroupName $distributionPointGroup
Start-CMContentDistribution -BootImageName "Boot Image (x86)" -DistributionPointGroupName $distributionPointGroup


# Setup SUP
###########

# Install Windows Server Role (WSUS)
Install-WindowsFeature -Name UpdateServices-Services,UpdateServices-DB -IncludeManagementTools

# WSUS Post Install Configuration
New-Item E:\WSUS -ItemType Directory
$wsusUtilExe = join-path "C:\Program Files\Update Services\Tools" -ChildPath "wsusutil.exe"
$wsusPostInstall = '"' + $wsusUtilExe + '"' + $wsusParameterSet
cmd /c $wsusPostInstall

Set-WsusServerSynchronization -SyncFromMU

# Test WSUS Initialization
# Set the Proxy
$config = (Get-WsusServer).GetConfiguration()
$config.GetContentFromMU = $true
$config.UseProxy = $false
# Choose Languages
$config.AllUpdateLanguagesEnabled = $false
$config.AllUpdateLanguagesDssEnabled = $false
$config.SetEnabledUpdateLanguages("en")
$config.Save()

# View enabled Languages
(Get-WsusServer).GetConfiguration().GetEnabledUpdateLanguages()

# Begin initial synchronization
$subscription = (Get-WsusServer).GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
    Write-Host "waiting on sync"
    Start-Sleep -Seconds 5
}

# Start WSUS Console First time wizard (no automation yet!)
exit

# Install SUP
Add-CMSoftwareUpdatePoint -SiteSystemServerName $siteServerFqdn -WsusIisPort 8530 -ClientConnectionType Internet `
    -UseProxy $false -UseProxyForAutoDeploymentRule $true -Verbose
# returns immediately, check Sitecomp.log

Start-Sleep -Seconds 300

# Configure SUP (Products, Classification,Languages)
$productArr = @("Windows 10","Office 2016")
$categoryArr = @("Critical Updates","Security Updates","Definition Updates","Update Rollups","Updates","Upgrades")
$languageArr = @("English","German")

$supSyncInterval = New-CMSchedule -Start (Get-Date -Hour 19 -Minute 00 -Second 00) -RecurInterval Days -RecurCount 1


# Cleanup Products
$oldArr = @("Office 2002/XP","Office 2003","Office 2007","Office 2010","Windows 7","Windows 8","Windows Defender","Windows Internet Explorer 7 Dynamic Installer","Windows Internet Explorer 8 Dynamic Installer","Windows Server 2003","Windows Server 2003, Datacenter Edition","Windows Server 2008","Windows Server 2008 R2","Windows Server 2008 Server Manager Dynamic Installer","Windows Server 2012","Windows Vista","Windows Vista Dynamic Installer","Windows XP","Windows XP 64-bit Edition Version 2003","Windows XP x64 Edition")
$oldLanguageArr = @("Chinese (Simplified, China)","French","German","Japanese","Russian")
Get-CMSoftwareUpdatePointComponent -SiteCode $siteCode | Set-CMSoftwareUpdatePointComponent -Verbose -RemoveProduct $oldArr `
    -SynchronizeAction SynchronizeFromMicrosoftUpdate -Schedule $supSyncInterval -RemoveLanguageUpdateFile $oldLanguageArr `
    -RemoveLanguageSummaryDetail $oldLanguageArr

# Start inital Sync for updated products and classifications
Sync-CMSoftwareUpdate -FullSync $true
$subscription = (Get-WsusServer).GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
    Write-Host "waiting on sync"
    Start-Sleep -Seconds 5
}

# Add desired products and classifications
Get-CMSoftwareUpdatePointComponent -SiteCode $siteCode | Set-CMSoftwareUpdatePointComponent -Verbose -AddUpdateClassification $categoryArr `
    -AddProduct $productArr -EnableCallWsusCleanupWizard $true -AddLanguageUpdateFile $languageArr

# Create SUP File Share
New-Item $supDir -ItemType Directory
Add-NewACE -DirectoryItem $supDir -User Administrators -AccessRule FullControl
New-SmbShare -Name SUP -Path $supDir -FullAccess Administrators

Sync-CMSoftwareUpdate -FullSync $true

# Setup Application Catalog Website
###################################

# Install Site System Roles
Add-CMApplicationCatalogWebServicePoint -SiteSystemServerName $siteServerFqdn -PortNumber 80
Add-CMApplicationCatalogWebsitePoint -SiteSystemServerName $siteServerFqdn -OrganizationName $orgaName -SiteCode $siteCode -CommunicationType Http -ApplicationWebServicePointServerName $siteServerFqdn

# Configure Branding Title
Set-CMClientSetting -BrandingTitle $orgaName -Name "Default Client Agent Settings" -ComputerAgent

# Configure Application Catalog Website
$portalUrl = "http://" + $siteServerFqdn + "/CMApplicationCatalog"
Set-CMClientSetting -Name "Default Client Agent Settings" -PortalUrl $portalUrl -ComputerAgent
Set-CMClientSetting -Name "Default Client Agent Settings" -AddPortalToTrustedSiteList $true -ComputerAgent

# Setup Client Installation Settings
####################################

Set-CMClientPushInstallation -SiteCode $siteCode -ChosenAccount $svcAccHash.Where({$_.Role -eq "PushAccount"}).AccountName `
    -InstallationProperty "SMSSITECODE=$siteCode SMSMP=$siteServerFqdn FSP=$siteServerFqdn DISABLECACHEOPT=TRUE"

# Setup Powershell in Client Settings
#####################################

Set-CMClientSetting -Name "Default Client Agent Settings" -PowerShellExecutionPolicy Bypass -ComputerAgent

# Setup Client Policy Polling Interval
######################################

Set-CMClientSetting -Name "Default Client Agent Settings" -PolicyPollingMins 15 -ClientPolicy

# Setup Client Hardware Inventory Interval
##########################################

$hvInvInterval = New-CMSchedule -Start (Get-Date -Hour 12 -Minute 00 -Second 00) -RecurInterval Days -RecurCount 1

Set-CMClientSetting -Name "Default Client Agent Settings" -HardwareInventory -Schedule $hvInvInterval

# Setup Client Software Inventory Interval
##########################################

$swInvInterval = New-CMSchedule -Start (Get-Date -Hour 13 -Minute 00 -Second 00) -RecurInterval Days -RecurCount 1

Set-CMClientSetting -Name "Default Client Agent Settings" -SoftwareInventory -Schedule $swInvInterval

# Setup Client Software Update Scan Interval
############################################

$supScanInterval = New-CMSchedule -Start (Get-Date -Hour 20 -Minute 00 -Second 00) -RecurInterval Days -RecurCount 1
$supReDeploymentInterval = New-CMSchedule -Start (Get-Date -Hour 20 -Minute 00 -Second 00) -RecurInterval Days -RecurCount 7

Set-CMClientSetting -Name "Default Client Agent Settings" -SoftwareUpdate -ScanSchedule $supScanInterval `
    -DeploymentEvaluationSchedule $supReDeploymentInterval -EnforceMandatory $true -BatchingTimeout 1 -TimeUnit Days


# Setup Deduplication on Sources Drive
###################################

Enable-DedupVolume -Volume E: -UsageType Default

# Setup Remote Control
######################

Set-CMClientSetting -RemoteControl -Name "Default Client Agent Settings" -FirewallExceptionProfile Domain `
    -PermittedViewer "ad\svs-sccm-remote"

New-CMAdministrativeUser -Name "ad\svs-sccm-remote" -RoleName "Remote Tools Operator" `
    -SecurityScopeName "Default"


# Setup SQL Reporting Services
##############################

New-CMAccount -UserName $svcAccHash.Where({$_.Role -eq "ReportingServicesAccount"}).AccountName -Password $svcAccHash.Where({$_.Role -eq "ReportingServicesAccount"}).Password -SiteCode $siteCode

Add-CMReportingServicePoint -FolderName ConfigMgr_$siteCode -ReportServerInstance SCCM -DatabaseServerName "$sqlServerFqdn\SCCM" `
    -DatabaseName CM_$siteCode -SiteCode $siteCode -SiteSystemServerName $sqlServerFqdn -UserName $svcAccHash.Where({$_.Role -eq "ReportingServicesAccount"}).AccountName