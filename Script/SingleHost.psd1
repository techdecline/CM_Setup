@{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowDomainUser = $true
            SourcePath = "\\CM-Server6\Install"
            DomainName = "decline"
            PSDSCAllowPlainTextPassword = $true
        }
        @{
            NodeName = "CM-Server6"
            Role = "ConfigMgr","SQLServer"
            #CertificateFile = "C:\Configs\PublicKeys\Server1.cer"
            InstanceName = "SCCM" # Required because of Single Server Setup
            }<#,
        @{
            NodeName = "CMTP_Server2"
            Role = "SQLServer"
            #CertificateFile = "C:\Configs\PublicKeys\Server2.cer"
            InstanceName = "SCCM"
            }#>
    )
}
# Save ConfigurationData in a file with .psd1 file extension