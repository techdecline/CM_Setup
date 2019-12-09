# Introduction
This project helps accelerating ConfigMgr deployments including documentation and post-installation jobs. Goal is to minimize deployment time by increasing standardization and documentation. 
As ConfigMgr does not allow installation using DSC, only pre-install is implemented using DSC. The actual ConfigMgr installation needs to be done manually.

# Getting Started
1. Create Folder Structure (C:\Install\SqlServer2017, C:\Install\SSMS, C:\Install\ADK)
2. Download SQL Server 2017 ISO and extract to C:\Install\SqlServer2017
3. Download SSMS from https://download.microsoft.com/download/D/D/4/DD495084-ADA7-4827-ADD3-FC566EC05B90/SSMS-Setup-ENU.exe and save to C:\Install\SSMS
4. Download SQL Reporting Services 2017 from https://download.microsoft.com/download/E/6/4/E6477A2A-9B58-40F7-8AD6-62BB8491EA78/SQLServerReportingServices.exe and copy sources to C:\Install\SqlServer2017RS
5. Mount Windows Server ISO and copy sources\sxs folder to C:\Install
6. Share C:\Install Folder with Read permissions for Everyone

# Install CM Prerequisites and Setup Host 
1. Download Repository to C:\Code
2. Update C:\Code\CM_Setup\SingleHost.psd1 according to your scenario.
3. Download required PS Modules (SqlServerDsc, NetworkingDsc)
4. Download ADK Installer and WinPE Addon for Windows 10 1909
5. Run both Installers and download all content to C:\Install\ADK\ADK1909 and C:\Install\ADK\ADK1909_PE
6. Run Script C:\Code\CM_Setup\Script\ConfigMgr.ps1
7. Apply Meta Config: Set-DscLocalConfigurationManager -Path C:\Code\CM_Setup\MOF
8. Apply DSC Config: Start-DscConfiguration -Wait -Force -Verbose -Path C:\Code\CM_Setup\MOF