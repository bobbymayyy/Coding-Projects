#!/bin/bash

#This script will present the user with a choice of lab deployment for Dev Ops

#==========================================================
clear
echo "=============================================="
echo "What would you like to deploy today?"
echo "Note - You'll need the password for Proxmox"
echo "=============================================="
echo "A - Bash Environment"
echo "B - Powershell Environment"
echo "C - Enterprise Lab"
echo "D - SCADA Lab"
echo "Z - Tear Down"
echo "=============================================="
read choice
clear
#==========================================================
echo "=============================================="
if [[ "$choice" =~ [aA] ]]; then
    echo "A - Bash Environment"
    cd ansible
    results=$(ansible-playbook -kK playbooks/11_deploy_bash.yml | tail -n 4)
    if [[ "$results" =~ [failed=0] ]]; then
        echo "Deployment of Bash Environment was successful."
        echo "Would you like to tear down before exiting? (y/n)"
        read exiting
        if [[ "$exiting" =~ [yY] ]]; then
            ansible-playbook -kK playbooks/99_tear_down.yml
        else
            exit 0
        fi
    else
        echo "Deployment was unsuccessful :("
        exit 0
    fi
elif [[ "$choice" =~ [bB] ]]; then
    echo "B"
elif [[ "$choice" =~ [cC] ]]; then
    echo "C"
elif [[ "$choice" =~ [dD] ]]; then
    echo "D"
elif [[ "$choice" =~ [zZ] ]]; then
    echo "Z - Tear Down"
    cd ansible
    ansible-playbook -kK playbooks/99_tear_down.yml
else
    echo "Thats not a choice :("
fi
echo "=============================================="