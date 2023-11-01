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
    ansible-playbook -kK playbooks/11_deploy_bash.yml
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