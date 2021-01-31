# Introduction
This project helps accelerating ConfigMgr deployments including documentation and post-installation jobs. Goal is to minimize deployment time by increasing standardization and documentation.
As ConfigMgr does not allow installation using DSC, only pre-install is implemented using DSC. The actual ConfigMgr installation needs to be done manually.

# Getting Started
1. Create Folder Structure (C:\Install\SqlServer2019, C:\Install\SSMS, C:\Install\ADK)
2. Download SQL Server 2019 ISO and extract to C:\Install\SqlServer2019
3. Download the latest SQL Server CU an extract to C:\Install\SqlServer2019CU
3. Download SSMS from https://aka.ms/ssmsfullsetup and save to C:\Install\SSMS
4. Download SQL Reporting Services 2019 from https://download.microsoft.com/download/1/a/a/1aaa9177-3578-4931-b8f3-373b24f63342/SQLServerReportingServices.exe and copy sources to C:\Install\SqlServer2019RS
5. Mount Windows Server ISO and copy sources\sxs folder to C:\Install
6. Share C:\Install Folder with Read permissions for Everyone

# Install CM Prerequisites and Setup Host
1. Download Repository to C:\Code
2. Update C:\Code\CM_Setup\SingleHost.psd1 according to your scenario.
3. Download required PS Modules (SqlServerDsc, NetworkingDsc)
4. Download ADK Installer and WinPE Addon for Windows 10 2004
5. Run both Installers and download all content to C:\Install\ADK\ADK2004 and C:\Install\ADK\ADK2004_PE
6. Run Script C:\Code\CM_Setup\Script\ConfigMgr.ps1
7. Apply Meta Config: Set-DscLocalConfigurationManager -Path C:\Code\CM_Setup\MOF
8. Apply DSC Config: Start-DscConfiguration -Wait -Force -Verbose -Path C:\Code\CM_Setup\MOF