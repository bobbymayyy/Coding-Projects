#!/bin/bash

clear
echo "============================================="
meridiem=$(date | awk '{print $5}')

if [[ "$meridiem" == AM ]]; then
    echo "Good Morning :)"
else
    echo "Good Afternoon :)"
fi

echo "=================="
echo "I am your virtual assistant to help deploy Defensive Security infrastructure."
echo "============================================="
echo "Press any key to continue..."
read -rsn1

clear
location=''

while [[ -z "$location" ]]; do
    echo "============================================="
    echo "I would like to get some information to and from you before we start."
    echo "---------------------------------------------"
    echo "I should be plugged into your laptop or the Proxmox node(s) that you have installed."
    echo "/////////////////////////////////////////////////////////////////////////////////////////////////////"
    echo "Laptop                                        |                                       Proxmox Node(s)"
    echo "-----------------------------------------------------------------------------------------------------"
    echo "Plug into Cisco's port 1                               Plug Proxmox management NIC into Cisco port 13"
    echo "Plug Cisco port 13 into Proxmox management NIC  May plug in laptop to Cisco port 1 but must assign IP"
    echo "Ansible will run pointed at Proxmox node(s)                          Ansible will run pointed at self"
    echo "-----------------------------------------------------------------------------------------------------"
    echo "/////////////////////////////////////////////////////////////////////////////////////////////////////"
    echo "POC for this infrastructure is SPC May for any other questions."
    echo "============================================="
    echo "Am I running from your laptop or a Proxmox Node? (l/p)"
    read location

    clear
    echo "============================================="

    if [[ "$location" =~ [lL] ]]; then
        echo "Laptop Control Node"
        echo "--------------------"
        echo "List out IP address(es) of the Proxmox nodes, pressing enter after each one. (CTRL-D when done.)"
        echo "--------------------"

        while read line; do
            prox_ips=("${prox_ips[@]}" $line)
        done

        echo "--------------------"
        echo "Putting us on the same subnet and testing connection."
        host_int=$(ip a | grep 'state UP' | awk '{print $2}' | awk -F: '{print $1}')
        echo "============================================="

        for i in $host_int; do
            ip a show $i
        done

        echo "============================================="
        echo "Which of these currently UP interfaces is connected to the same subnet as Proxmox?"
        echo "The name after the number please..."
        read host_int

        echo "============================================="
        echo "Are we airgapped? (y/n)"
        read airgap

        echo "One second..."
        oct1=$(echo "${prox_ips[0]}" | awk -F. '{print $1}')
        oct2=$(echo "${prox_ips[0]}" | awk -F. '{print $2}')
        oct3=$(echo "${prox_ips[0]}" | awk -F. '{print $3}')
        ip addr flush dev $host_int
        ip addr add $oct1.$oct2.$oct3.68/24 dev $host_int
        
        if [[ "$airgap" =~ [nN] ]]; then
            echo "Adding default route since we are not airgapped..."
            for i in {1,2,254}; do
                route add default gw $oct1.$oct2.$oct3.$i dev $host_int
                ping -c 1 8.8.8.8 | grep 'bytes from' || route del default gw $oct1.$oct2.$oct3.$i dev $host_int && break
            done
        else
            echo "No default route needed since we are airgapped..."
        fi

        sleep 5
        
        for i in "${prox_ips[@]}"; do
            test=$(ping -c 1 $i | grep 'bytes from' &)
        done

        if [[ -n "$test" && -n "$google_test" ]]; then
            echo "Successful connection(s)."        
        else
            echo "Failed connection(s)."
        fi

    elif [[ $location =~ [pP] ]]; then
        echo "Proxmox Control Node"
    else
        echo "Please specify using l or p, respectively."
        location=''
    fi

done
















#All this will be commented out for now...
: '
clear
echo "============================================="
choice=n
info_choice=n
while [[ "$choice" =~ [nN] ]]; do
    echo "I have quite a bit of resources on the USB I am running from..."
    echo "---------------------------------------------"
    ls -la .
    echo "============================================="
    echo "Have you already installed Proxmox baremetal on the node(s) you would like to use? (y/n)"
    read choice
    if [[ "$choice" =~ [nN] ]]; then
        clear
        echo "============================================="
        echo "Would you like a walkthrough of the graphical install for Proxmox?"
        read info_choice
        if [[ "$info_choice" =~ [nN] ]]; then
            clear
            echo "============================================="
            echo "No problem, go ahead and do that now.. then come back and run me again."
        elif [[ "$info_choice" =~ [yY] ]]; then
            clear
            echo "============================================="
            echo "Sure :)"
            echo "Agree to terms and conditions >"
            echo "---------"
            echo "Choose your storage that you made with BIOS or PERC (No need for changing options) >"
            echo "---------"
            echo "Put a country and timezone >"
            echo "---------"
            echo "Provide a root password for CLI and GUI login (Email can be defender@cpb.mil) >"
            echo "---------"
            echo "Choose your PROXMOX management interface (you need to be able to connect to this NIC from the computer you are on)"
            echo "Hostname can be set to <ANYTHING>.cpb.mil (may or may not need gateway but can be added after install)"
            echo "DNS server should be something like 8.8.8.8 if you have access to the internet through PROXMOX management interface and not using DHCP >"
            echo "---------"
            echo "Finish install >"
            echo "============================================="
        else
            clear
            echo echo "============================================="
            echo "Thats not a choice :("
            info_choice=n
        fi
    elif [[ "$choice" =~ [yY] ]]; then
        clear
        echo "============================================="
        echo "Okay :)"
    else
        clear
        echo "============================================="
        echo "Thats not a choice :("
        choice=n
    fi
done

echo "=================="
echo "What IP address did you assign to the Proxmox management interface when you installed?"
read prox_ip
echo "============================================="
echo "One second..."

host_int=$(ip a | grep 'state UP' | awk '{print $2}' | awk -NF: '{print $1}')
clear
echo "============================================="
for i in $host_int; do
    ip a show $i
done
echo "============================================="
echo "Which of these currently UP interfaces is connected to the same subnet as Proxmox?"
echo "The name after the number please..."
read prox_int

choice=n
while [[ "$choice" =~ [nN] ]]; do
    clear
    echo "============================================="
    ip a show $prox_int
    echo "============================================="
    echo "Is this the correct choice? (y/n)"
    read choice
    if [[ "$choice" =~ [nN] ]]; then
        clear
        echo "============================================="
        for i in $host_int; do
            ip a show $i
        done
        echo "============================================="
        echo "Which of these currently UP interfaces is connected to the same subnet as Proxmox?"
        echo "The name after the number please..."
        read prox_int
    elif [[ "$choice" =~ [yY] ]]; then
        clear
        echo "============================================="
        echo "Okay :)"
    else
        clear
        echo "============================================="
        echo "Thats not a choice :("
        choice=n
    fi
done

echo "=================="
ip a show $prox_int
echo "============================================="
echo "Did you assign this IP address statically or with DHCP? (s/d)"
read ip_negotiation

if [[ "$ip_negotiation" =~ [sS] ]]; then
    clear
    echo "============================================="
    echo "Okay :)"
    host_ip=$(ip a show $prox_int | grep 'inet ' | awk '{print $2}' | awk -F/ '{print $1}')
    echo "One second..."
elif [[ "$ip_negotiation" =~ [dD] ]]; then
    clear
    echo "============================================="
    echo "Okay :)"
    echo "Running DHClient..."
    dhclient -v
    host_ip=$(ip a show $prox_int | grep 'inet ' | awk '{print $2}' | awk -F/ '{print $1}')
    if [[ $host_ip =~ [169.254.*] ]]; then
        echo "APIPA will not work for this..."
        echo "Something is wrong and the networking needs to be looked at to see why you are not getting a DHCP address."
        echo "This could also be the case if you did not set up DHCP on your own for the same subnet as Proxmox management."
    else
        echo "One second..."
    fi
else
    clear
    echo "============================================="
    echo "Thats not a choice :("
fi

host_octets+=($(echo $host_ip | awk -F. '{print $1}'))
host_octets+=($(echo $host_ip | awk -F. '{print $2}'))
host_octets+=($(echo $host_ip | awk -F. '{print $3}'))
host_octets+=($(echo $host_ip | awk -F. '{print $4}'))
prox_octets+=($(echo $prox_ip | awk -F. '{print $1}'))
prox_octets+=($(echo $prox_ip | awk -F. '{print $2}'))
prox_octets+=($(echo $prox_ip | awk -F. '{print $3}'))
prox_octets+=($(echo $prox_ip | awk -F. '{print $4}'))

if [[ $(echo "${host_octets[0]}") == $(echo "${prox_octets[0]}") ]] && [[ $(echo "${host_octets[1]}") == $(echo "${prox_octets[1]}") ]] && [[ $(echo "${host_octets[2]}") == $(echo "${prox_octets[2]}") ]]; then
    clear
    echo "============================================="
    echo "You are in the same subnet as your Proxmox installation."
    echo "Testing connection..."
    echo "----------------"
    test=$(ping -c 3 $prox_ip | grep 'bytes from')
    if [[ -z $test ]]; then
        echo "Connection test failed."
        echo "Attempting to correct the situation..."
    else
        echo "Connection test successful."
        echo "Moving on..."
    fi
else
    clear 
    echo "============================================="
    echo "You are not in the same subnet as your Proxmox installation."
    echo "Attempting to correct the situation..."
    ip addr del $host_ip/24 dev $host_int
    ip addr add $(echo "${prox_octets[0]}").$(echo "${prox_octets[1]}").$(echo "${prox_octets[2]}").69/24 dev $host_int
    echo "Testing connection..."
    echo "----------------"
    test=$(ping -c 3 $prox_ip | grep 'bytes from')
    if [[ -z $test ]]; then
        echo "Connection test failed."
        echo "Attempting to correct the situation..."
    else
        echo "Connection test successful."
        echo "Moving on..."
    fi
fi

clear
echo "============================================="
echo "We are going to add the Proxmox SSH fingerprint to our computer now so we can log in without a password."
echo "You can hit enter through creating your public key so it saves in the default location and allows for no passphrase."
ssh-keygen -t rsa -b 2048
ssh-copy-id root@$prox_ip

ssh root@$prox_ip 'echo "Hello :)"' && clear; echo "Passwordless configuration was successful."

echo "============================================="
echo "I am going to finalize some things and ask you a few more questions so we can start the Ansible."
echo "----------------"

echo "Where would you like to install Ansible?"
echo "This will dictate where it runs from as it allows you to choose the control node."
echo "----------------"
echo "A - This Laptop"
echo "B - Proxmox Node(s)"
echo "============================================="
read ansible_choice



apt=$(which apt 2>/dev/null)
dnf=$(which dnf 2>/dev/null)

if [[ -n $apt ]]; then
    echo "I see you are using a Debian based distribution of Linux..."
    echo "Installing Ansible and its dependencies needed for this exercise..."
    dpkg -i ./packages/ansible/debs/*.deb
elif [[ -n $dnf ]]; then
    echo "I see you are using a Red-Hat based distribution of Linux..."
    echo "Installing Ansible and its dependencies needed for this exercise..."
    rpm -i ./packages/ansible/rpms/*.rpm
else
    echo "You do not have apt or dnf as a package manager, so I can not extrapolate how to install the .deb or .rpm files I have for you."
    echo "They are not needed to move on, if you have them you can install them and re-run me; but we are going to install ansible on the Proxmox."
fi

ssh root@$prox_ip 'mkdir debs'
scp ./packages/ansible/debs/*.deb root@$prox_ip:

echo "/////////////////////////////////////////////"
echo "Goodbye :)"
'