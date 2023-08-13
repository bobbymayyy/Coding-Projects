###############################################################################
#NIC/Rename

#Define the Computer Name
$ComputerName = "DC1"

#Define the IPv4 Addressing
$IPv4Address = "192.168.2.2"
$IPv4Prefix = "24"
$IPv4GW = "192.168.2.1"
$IPv4DNS = "8.8.8.8"

#Get the Network Adapter's Prefix
$NICPrefix = (Get-NetAdapter).ifIndex

#Turn off IPv6 Random & Temporary IP Assignments
Set-NetIPv6Protocol -RandomizeIdentifiers Disabled
Set-NetIPv6Protocol -UseTemporaryAddresses Disabled

#Turn off IPv6 Transition Technologies
Set-Net6to4Configuration -State Disabled
Set-NetIsatapConfiguration -State Disabled
Set-NetTeredoConfiguration -Type Disabled

#Add IPv4 Address, Gateway, and DNS
New-NetIPAddress -InterfaceIndex $NICPrefix -IPAddress $IPv4Address -PrefixLength $IPv4Prefix -DefaultGateway $IPv4GW
Set-DNSClientServerAddress –interfaceIndex $NICPrefix –ServerAddresses $IPv4DNS

#Rename the Computer, and Restart
Rename-Computer -NewName $ComputerName -Force
Restart-Computer