#!/bin/bash

#Depending on the option given, this script will list out information for mirrors, assist in deleting mirrors, or assist in creating them.
#Or, if no option; it will just give a suggestion.
if [[ "$1" == list ]]; then
    	#This will only list out relevant information
    	clear
    	echo "========================================================================"
    	read -p "Do you want to look at 'mirror' info or 'bridge' info: " selection
    	clear
    	#Get input for a info command selection.

    	#-----------------------------------
    	if [[ "$selection" =~ mirror ]]; then
            	echo "========================================================================"
            	ovs-vsctl list mirror
            	echo "========================================================================"

    	elif [[ "$selection" =~ bridge ]]; then
            	echo "========================================================================"
            	cat /etc/network/interfaces | egrep --before-context 3 --after-context 1 'OVSBridge'
            	echo "========================================================================"

    	fi
    	#List out information based on user selection.

    	#-----------------------------------
    	echo "Bye :)"

elif [[ "$1" == delete ]]; then
    	#This will delete the mirrors associated with existing OVS bridges using the mirror name to extrapolate the bridge name.
    	clear
    	echo "========================================================================"
    	ovs-vsctl list mirror
    	#List out existing mirrors.

    	#-----------------------------------
    	echo "========================================================================"
    	read -p "Enter one mirror name (case insensitive): " mirror
    	clear
    	#Get input for mirror name.

    	#-----------------------------------
    	bridge_comment=$(ovs-vsctl list mirror | egrep -i "$mirror" | awk '{print $3}' | egrep -o "\w+[^mirror]")
    	cat /etc/network/interfaces | egrep --before-context 4 $bridge_comment
    	#Extrapolate bridge information from mirror name.

    	#-----------------------------------
    	echo "========================================================================"
    	read -p "Enter mirror again to confirm or enter a different one: " mirror
    	clear
    	#Get input again to confirm or change mind.

    	#-----------------------------------
    	bridge_comment=$(ovs-vsctl list mirror | egrep -i "$mirror" | awk '{print $3}' | egrep -o "\w+[^mirror]")
    	bridge=$(cat /etc/network/interfaces | egrep --before-context 4 $bridge_comment | egrep "auto" | awk '{print $2}')
    	#Extrapolate bridge name from mirror name.

    	#-----------------------------------
    	echo "========================================================================"
    	echo "Clearing existing mirrors in extrapolated bridge..."
    	echo "========================================================================"
    	sleep 5
    	ovs-vsctl clear bridge $bridge mirrors
    	clear
    	#Delete mirrors in extrapolated bridge.

    	#-----------------------------------
    	ovs-vsctl list mirror
    	#List remaining mirrors.
    	echo "Bye :)"

elif [[ "$1" == setup ]]; then
    	#This will deploy the mirrors to existing OVS bridges using the taps activated by deployment and power of Sec O Sensor.
    	clear
    	echo "========================================================================"
    	cat /etc/network/interfaces | egrep --before-context 3 --after-context 1 'OVSBridge'
    	echo "========================================================================"
    	#Display the available OVS bridges.

    	#-----------------------------------
    	read -p "Enter one bridge name in the form of vmbr* (case sensitive): " bridge
    	clear
    	cat /etc/network/interfaces | egrep --after-context 4 $bridge
    	#Get input for bridge name and display information about the specific bridge.

    	#-----------------------------------
    	echo "========================================================================"
    	read -p "Enter bridge again to confirm or enter a different one: " bridge
    	clear
    	cat /etc/network/interfaces | egrep --after-context 4 $bridge
    	#Get input again and display one more time for reference when choosing Sec O sensor.

    	#-----------------------------------
    	mirror_name=$(cat /etc/network/interfaces | egrep --after-context 4 $bridge | egrep "#")
    	mirror_name=${mirror_name/*#/}
    	#Store the future name of the mirror from the selected bridge's comment in Proxmox.

    	#-----------------------------------
    	echo "========================================================================"
    	read -p "Enter the VM name of the Security Onion sensor you want to ingest this bridge (case insensitive): " sensor
    	clear
    	seco_vmid=$(qm list | egrep -i $sensor | grep running | awk '{print $1}')
    	#Get input for Sec O sensor VM name and store extrapolated Security Onion sensor VM ID.

    	#-----------------------------------
    	#vm_ids=()
    	#vm_ids+=($(echo $seco_vmid | grep -E -o '[^ ]+'))
    	#printf '%s\n' "${vm_ids[1]}"
    	#Sleep deprived frenzy; deprecated because there should be no use for multiple sensors in one subnet.

    	#-----------------------------------
    	echo "========================================================================"
    	echo "Clearing existing mirrors in selected bridge..."
    	sleep 5
    	ovs-vsctl clear bridge $bridge mirrors
    	#Clear existing mirrors in selected bridge.

    	#-----------------------------------
    	echo "------------------------------------------------------------------------"
    	echo "Creating mirror, setting SPAN, and pointing to selected Sec O sensor..."
    	echo "========================================================================"
    	ovs-vsctl -- --id=@m create mirror name=$mirror_name"mirror" -- add bridge $bridge mirrors @m
    	#Create new mirror based off bridge name and manufactured mirror name.

    	#-----------------------------------
    	int_id=$(ovs-vsctl show | egrep '^\s+Bridge|^\s+Port\stap'$seco_vmid'' | egrep --after-context 1 $bridge | egrep '^\s+Port' | awk '{print $2}')
    	#Store tap interface ID based off Sec O sensor VM ID and bridge.

    	#-----------------------------------
    	ovs-vsctl -- --id=@$int_id get port $int_id -- set mirror $mirror_name"mirror" select_all=true output-port=@$int_id
    	sleep 15
    	#Create the SPAN and set output port based off tap interface ID and manufactured mirror name.

    	#-----------------------------------
    	clear
    	echo "========================================================================"
    	echo "Mirroring:"
    	ovs-vsctl list mirror | egrep --after-context 8 "$mirror_name"
    	echo "========================================================================"
    	cat /etc/network/interfaces | egrep --after-context 4 $bridge
    	echo "========================================================================"
    	#List out information about your new mirror and relating bridge.
    	echo "Bye :)"

else
    	echo "Please try to run with an option; setup, list, or delete.
---------------------------------------------------
For example: ./deploy-mirrors.sh list"

fi
