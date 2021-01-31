configuration ConfigMgr
{
    param (
        [Parameter(Mandatory=$true)]
        [PSCredential]$SetupCredential,

        [Parameter(Mandatory=$true)]
        [PSCredential]$SqlServiceAccount
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Name SQLSetup
    Import-DscResource -Name SqlWindowsFirewall
    Import-DscResource -Name Firewall
    Import-DSCResource -name sqlServerNetwork

    node $AllNodes.Where{$_.Role -eq "ConfigMgr"}.NodeName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature NET-Framework-Features
        {
            Ensure = "Present"
            Name = "NET-Framework-Features"
            IncludeAllSubFeature = $true
            Source = (Join-Path $Node.SourcePath -ChildPath "sxs")
        }

        WindowsFeature NET-Framework-45-Features
        {
            Ensure = "Present"
            Name = "NET-Framework-45-Features"
            IncludeAllSubFeature = $true
        }

        WindowsFeature BITS
        {
            Ensure = "Present"
            Name = "BITS"
        }

        WindowsFeature RDC
        {
            Ensure = "Present"
            Name = "RDC"
        }

        WindowsFeature Web-Asp-Net
        {
            Ensure = "Present"
            Name = "Web-Asp-Net"
        }

        WindowsFeature Web-Asp-Net45
        {
            Ensure = "Present"
            Name = "Web-Asp-Net45"
        }

        WindowsFeature Web-Windows-Auth
        {
            Ensure = "Present"
            Name = "Web-Windows-Auth"
        }

        WindowsFeature Web-Mgmt-Compat
        {
            Ensure = "Present"
            Name = "Web-Mgmt-Compat"
            IncludeAllSubFeature = $true
        }

        WindowsFeature Web-Scripting-Toolsst
        {
            Ensure = "Present"
            Name = "Web-Scripting-Tools"
        }

        WindowsFeature WSUS
        {
            Ensure = "Present"
            Name = "UpdateServices-DB"
        }

        WindowsFeature WSUSMgmtToolsAPI
        {
            Ensure = "Present"
            Name = "UpdateServices-API"
            DependsOn = "[WindowsFeature]WSUS"
        }

        WindowsFeature WSUSMgmtToolsUI
        {
            Ensure = "Present"
            Name = "UpdateServices-UI"
            DependsOn = "[WindowsFeature]WSUS"
        }

        WindowsFeature Dedup
        {
            Ensure = "Present"
            Name = "FS-Data-Deduplication"
        }

        Package ("WADK" + $Node.NodeName)
        {
            Ensure = "Present"
            Path  = join-path $Node.sourcePath -childpath "ADK\ADK2004\adksetup.exe"
            Name = "Windows Assessment and Deployment Kit - Windows 10"
            Credential=$SetupCredential
            ProductId = "{9346016b-6620-4841-8ea4-ad91d3ea02b5}"
            Arguments = "/features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /quiet /log $env:Temp\ADK.log /forcerestart"
        }

        Package ("WADK_PE" + $Node.NodeName)
        {
            Ensure = "Present"
            Path  = join-path $Node.sourcePath -childpath "ADK\ADK2004_PE\adkwinpesetup.exe"
            Name = "Windows Assessment and Deployment Kit Windows Preinstallation Environment Add-ons - Windows 10"
            Credential=$SetupCredential
            ProductId = "{353df250-4ecc-4656-a950-4df93078a5fd}"
            Arguments = "/features OptionId.WindowsPreinstallationEnvironment /quiet /log $env:Temp\ADK.log /forcerestart"
        }
    }

    node $AllNodes.Where{$_.Role -eq "SQLServer"}.NodeName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature DotNet3
        {
            Name = "NET-Framework-Core"
            Ensure = "Present"
            Source = (join-path $Node.SourcePath -ChildPath "sxs")
        }

        SqlSetup ($Node.NodeName + $Node.InstanceName)
        {
            DependsOn = "[WindowsFeature]DotNet3"
            SourcePath = (join-path $Node.SourcePath -ChildPath "SQLServer2019")
            InstanceName = $Node.InstanceName
            Features = "SQLENGINE"
            UpdateEnabled = "0"
            SQLCollation = "SQL_Latin1_General_CP1_CI_AS"
            #InstallSharedDir = "C:\Program Files\Microsoft SQL Server"
            InstallSharedDir = join-path -Path $node.SqlInstallDriveLetter -childPath "Program Files\Microsoft SQL Server"
            InstallSharedWOWDir = join-path -Path $node.SqlInstallDriveLetter -childPath "Program Files (x86)\Microsoft SQL Server"
            InstanceDir = join-path -Path $node.SqlInstanceDriveLetter -childPath "Program Files\Microsoft SQL Server"
            SQLSvcAccount = $SqlServiceAccount
            SQLTempDBDir = join-path -Path $node.SqlTempDriveLetter -ChildPath "SQLTempDB"
            SQLBackupDir = join-path -Path $node.SqlBackupDriveLetter -ChildPath "SQLBackup"
            SQLSysAdminAccounts = $node.SqlSysAdminAccounts
        }

        Package ("SQL-CU8" + $Node.InstanceName)
        {
            DependsOn = ("[SqlSetup]" + $Node.NodeName + $Node.InstanceName)
            Ensure = "Present"
            Path = (join-path $Node.SourcePath -ChildPath "SQLServer2019CU8\Setup.exe")
            Name = "Hotfix 4073 for SQL Server 2019 (KB4577194) (64-bit)"
            Credential=$SetupCredential
            ProductId = ""
            Arguments = "/quiet /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances"
        }

        Package ($Node.NodeName + $Node.InstanceName)
        {
            DependsOn = ("[SqlSetup]" + $Node.NodeName + $Node.InstanceName)
            Path = (join-path $Node.SourcePath -ChildPath "SQLServer2019RS\SQLServerReportingServices.exe")
            Name = "SQL Server 2019 Reporting Services"
            Credential=$SetupCredential
            ProductId = "{4b685015-f3d6-4fc3-9dbd-97ec3f0ed795}"
            Arguments = "/passive /norestart /IAcceptLicenseTerms /log $env:Temp\SQLReportingServices.log"
        }

        SqlWindowsFirewall ($Node.NodeName + $Node.InstanceName)
        {
            DependsOn = ("[SqlSetup]" + $Node.NodeName + $Node.InstanceName)
            SourcePath = (join-path $Node.SourcePath -ChildPath "SQLServer2017")
            InstanceName = $Node.InstanceName
            Features = "SQLENGINE"
        }

        sqlServerNetwork ($Node.NodeName + $Node.InstanceName)
        {
            DependsOn = ("[SqlSetup]" + $Node.NodeName + $Node.InstanceName)
            InstanceName = $Node.InstanceName
            ProtocolName = "tcp"
            RestartService = $true
            TcpDynamicPort = $false
            TcpPort = "1433"
        }

        Firewall ($Node.NodeName + "_RPC")
        {
            Name                  = "RemoteEventLogSvc-In-TCP"
            Ensure                = "Present"
            Enabled               = "True"
        }

        Firewall ($Node.NodeName + "_ICMP")
        {
            Name                  = "FPS-ICMP4-ERQ-In"
            Ensure                = "Present"
            Enabled               = "True"
        }

        Firewall ($Node.NodeName + "_SMB")
        {
            Name                  = "FPS-SMB-In-TCP"
            Ensure                = "Present"
            Enabled               = "True"
        }

        Firewall ($Node.NodeName + "_WMI_Async")
        {
            Name                  = "WMI-ASYNC-In-TCP"
            Ensure                = "Present"
            Enabled               = "True"
        }

        Firewall ($Node.NodeName + "_WMI_DCOM")
        {
            Name                  = "WMI-RPCSS-In-TCP"
            Ensure                = "Present"
            Enabled               = "True"
        }

        Firewall ($Node.NodeName + "_WMI_In")
        {
            Name                  = "WMI-WINMGMT-In-TCP"
            Ensure                = "Present"
            Enabled               = "True"
        }

        Package MgmtStudio
        {
            Ensure = "Present"
            Path  = (join-path $Node.SourcePath -ChildPath "SSMS\SSMS-Setup-ENU.exe")
            Name = "Microsoft SQL Server Management Studio - 18.8"
            Credential=$SetupCredential
            ProductId = "{03FFD0DE-C109-45D1-9C19-C010A02CFC73}"
            Arguments = "/install /silent /norestart"
        }
    }
}

$setupCred = Get-Credential -Message "Enter Setup Credentials"
$LocalSystemCred = New-Object System.Management.Automation.PSCredential "SYSTEM",(ConvertTo-SecureString -AsPlainText "blabla" -Force)
ConfigMgr -OutputPath 'C:\Code\CM_Setup\MOF' `
    -ConfigurationData "C:\Code\CM_Setup\Script\SingleHost.psd1" -SetupCredential $setupCred -SqlServiceAccount $LocalSystemCred