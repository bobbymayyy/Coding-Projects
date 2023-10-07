############################################################################
#ADDS and Promote

$DomainName  = ""
$netBIOSName = "purple"
$DomainMode  = "Win2012R2"
$Password = ''

Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools

Import-Module ADDSDeployment

$ForestProperties = @{

    DomainName           = $DomainName
    DomainnetBIOSName    = $netBIOSName
    ForestMode           = $DomainMode
    DomainMode           = $DomainMode
    CreateDnsDelegation  = $False
    InstallDns           = $True
    DatabasePath         = "C:\Windows\NTDS"
    LogPath              = "C:\Windows\NTDS"
    SysvolPath           = "C:\Windows\SYSVOL"
    NoRebootOnCompletion = $False
    Force                = $True
    SafeModeAdministratorPassword = ConvertTo-SecureString $Password -AsPlainText -Force

}

Install-ADDSForest @ForestProperties

