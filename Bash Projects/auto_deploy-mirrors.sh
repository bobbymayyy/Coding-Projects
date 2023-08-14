#!/bin/bash

#This will auto deploy mirrors based on agreed upon bridges.
clear
echo "Automatically setting up mirrors based on bridges."
echo "======================================================================"
cat /etc/network/interfaces | egrep -i --before-context 4 '#DMZ'
#It is worth mentioning this is for DMZ/Core communication ONLY. As such, this is set up separately.

#----------------------------------
echo "------------------------------------------------------------"
cat /etc/network/interfaces | egrep -i --before-context 4 '#WORKSTATIONS'
echo "------------------------------------------------------------"
cat /etc/network/interfaces | egrep -i --before-context 4 '#SERVERS'
echo "------------------------------------------------------------"
cat /etc/network/interfaces | egrep -i --before-context 4 '#SPECIAL'
echo "======================================================================"
#List out information regarding the bridges to be mirrored.

#----------------------------------
declare -A bridges
dmz_bridge=$(cat /etc/network/interfaces | egrep -i --before-context 4 '#DMZ' | egrep "auto" | awk '{print $2}')
bridges[WORKSTATIONS]=$(cat /etc/network/interfaces | egrep -i --before-context 4 '#WORKSTATIONS' | egrep "auto" | awk '{print $2}')
bridges[SERVERS]=$(cat /etc/network/interfaces | egrep -i --before-context 4 '#SERVERS' | egrep "auto" | awk '{print $2}')
bridges[SPECIAL]=$(cat /etc/network/interfaces | egrep -i --before-context 4 '#SPECIAL' | egrep "auto" | awk '{print $2}')
#This puts the bridge names in a dictionary as values with comments as keys. Add more bridges to mirror here by utilizing appropriate bridge comments.

#----------------------------------
seco_vmid=$(qm list | egrep -i sensor | grep running | awk '{print $1}')
vm_ids=()
vm_ids+=($(echo $seco_vmid | grep -E -o '[^ ]+'))
vm_id_num="${#vm_ids[@]}"
vm=0
#Gets the VM IDs of any VMs containing 'sensor' and puts them in an array.

#----------------------------------
for bridge in "${!bridges[@]}"; do
        #echo "${bridges[$bridge]}"
        ovs-vsctl clear bridge "${bridges[$bridge]}" mirrors
        if [[ vm -lt vm_id_num ]]; then
                #echo "${vm_ids[$vm]}"
                ovs-vsctl -- --id=@m create mirror name="$bridge"'mirror' -- add bridge "${bridges[$bridge]}" mirrors @m
                int_id=$(ovs-vsctl show | egrep '^\s+Bridge|^\s+Port\stap'${vm_ids[$vm]}'' | egrep --after-context 1 "${bridges[$bridge]}" | egrep '^\s+Port' | awk '{print $2}')
                ovs-vsctl -- --id=@$int_id get port $int_id -- set mirror "$bridge"'mirror' select_all=true output-port=@$int_id
                vm+=1
        else
                vm=0
                #echo "${vm_ids[$vm]}"
                ovs-vsctl -- --id=@m create mirror name="$bridge"'mirror' -- add bridge "${bridges[$bridge]}" mirrors @m
                int_id=$(ovs-vsctl show | egrep '^\s+Bridge|^\s+Port\stap'${vm_ids[$vm]}'' | egrep --after-context 1 "${bridges[$bridge]}" | egrep '^\s+Port' | awk '{print $2}')
                ovs-vsctl -- --id=@$int_id get port $int_id -- set mirror "$bridge"'mirror' select_all=true output-port=@$int_id
                vm+=1

        fi
        unset bridges[$bridge]

done
#Extrapolate VM ID for running Sec O sensor/s and split bridges between them equally.

#----------------------------------
corevm_id=$(qm list | egrep -i 'CORE' | grep running | awk '{print $1}')
coreint_id=$(ovs-vsctl show | egrep '^\s+Bridge|^\s+Port\sfwln'$corevm_id'' | egrep --after-context 1 $dmz_bridge | egrep '^\s+Port' | awk '{print $2}')
dmzvm_id=$(qm list | egrep -i 'DMZ' | grep running | awk '{print $1}')
dmzint_id=$(ovs-vsctl show | egrep '^\s+Bridge|^\s+Port\sfwln'$dmzvm_id'' | egrep --after-context 1 $dmz_bridge | egrep '^\s+Port' | awk '{print $2}')

int_id=$(ovs-vsctl show | egrep '^\s+Bridge|^\s+Port\stap'${vm_ids[$vm]}'' | egrep --after-context 1 $dmz_bridge | egrep '^\s+Port' | awk '{print $2}')

ovs-vsctl clear bridge $dmz_bridge mirrors
ovs-vsctl -- --id=@m create mirror name=DMZCOREmirror -- add bridge $dmz_bridge mirrors @m 
ovs-vsctl -- --id=@$coreint_id get port $coreint_id -- --id=@$dmzint_id get port $dmzint_id -- set mirror DMZCOREmirror select_src_port=[@$coreint_id,@$dmzint_id] select_dst_port=[@$coreint_id,@$dmzint_id]
ovs-vsctl -- --id=@$int_id get port $int_id -- set mirror DMZCOREmirror output-port=@$int_id
#Setup mirror for DMZ/Core specifically.

#----------------------------------
sleep 15
clear
echo "Now mirroring:"
echo "======================================================================="
ovs-vsctl list mirror
echo "======================================================================="
#List out information regarding the bridges now mirrored.

echo "Bye :)"