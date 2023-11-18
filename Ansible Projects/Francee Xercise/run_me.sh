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
echo "You can plug the laptop I am on into the first port on the switch and you will be able to statically assign yourself an IP in the subnet you will or have created."
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

clear
echo "============================================="
choice=n
while [[ "$choice" =~ [nN] ]]; do
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
echo "Is this the correct choice? (y/n)"


echo "Goodbye :)"