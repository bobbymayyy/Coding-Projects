############################################################################
#DNS/S&S/Time

#Define DNS and Sites & Services Settings
$IPv4netID = "192.168.2.0/24"
$SiteName = "Purple"
$Location = "Purple Mattress"

#Define Authoritative Internet Time Servers
$TimePeerList = "0.us.pool.ntp.org 1.us.pool.ntp.org"

#Add DNS Reverse Lookup Zones
Add-DNSServerPrimaryZone -NetworkID $IPv4netID -ReplicationScope 'Forest' -DynamicUpdate 'Secure'

#Make Changes to Sites & Services
$DefaultSite = Get-ADReplicationSite | Select DistinguishedName
Rename-ADObject $DefaultSite.DistinguishedName -NewName $SiteName
New-ADReplicationSubnet -Name $IPv4netID -site $SiteName -Location $Location

#Re-Register DC's DNS Records
Register-DnsClient

#Enable Default Aging/Scavenging Settings for All Zones and this DNS Server
Set-DnsServerScavenging –ScavengingState $True –ScavengingInterval 7:00:00:00 –ApplyOnAllZones
$Zones = Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $False -and $_.ZoneName -ne 'TrustAnchors'}
$Zones | Set-DnsServerZoneAging -Aging $True

#Set Time Configuration
w32tm /config /manualpeerlist:$TimePeerList /syncfromflags:manual /reliable:yes /update

############################################################################
#Recycle Bin

$ForestFQDN = "purple.mat"
$SchemaDC   = "dc1.purple.mat"

Enable-ADOptionalFeature –Identity 'Recycle Bin Feature' –Scope ForestOrConfigurationSet –Target $ForestFQDN -Server $SchemaDC -confirm:$False

###########################################################################
#ADDS Snapshot

C:\Windows\system32\ntdsutil.exe snapshot "activate instance ntds" create quit quit