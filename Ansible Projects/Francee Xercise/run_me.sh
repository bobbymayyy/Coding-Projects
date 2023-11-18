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

echo "I am your virtual assistant to help deploy Defensive Security infrastructure for your exercise in France; you can call me Francee Xercise."
echo "============================================="
echo "Press any key to continue..."
read -rsn1

clear
echo "============================================="
echo "I would like to give you some helpful tips before we get started."
echo "---------------------------------------------"
echo "The Proxmox that you have installed or plan to install should be located in the same subnet as us so that the Ansible I run can see the Proxmox."
echo "The Cisco switch has been updated to have vlans separating the Proxmox management and Security Onion management for this exercise."
echo "You can plug the laptop I am on into the first port on the switch and you should statically assign yourself an IP in the subnet you will or have created."
echo "This script assumes you are using a CIDR of 24 as this subnet will only be for the administration of Proxmox."
echo "You can then plug the switch into one of the ports on the node(s)."
echo "POC for this infrastructure is SPC May for any other questions."
echo "============================================="
echo "Press any key to continue..."
read -rsn1

clear
echo "============================================="
choice=n
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
        echo "No problem, go ahead and do that now.. then come back and run me again."
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

for i in $(echo $host_ip | awk -F. '{print $0}'); do
    host_octets+=($i)
done
echo "${host_octets[-1]}"

echo "Goodbye :)"