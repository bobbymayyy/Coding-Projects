#!/bin/bash

#This script will present the user with a choice of lab deployment for Dev Ops

#==========================================================
clear
echo "=============================================="
echo "What would you like to deploy today?"
echo "=============================================="
echo "A - Bash Environment"
echo "B - Powershell Environment"
echo "C - Enterprise Lab"
echo "D - SCADA Lab"
echo "=============================================="
read choice
clear
#==========================================================
echo "=============================================="
if [[ "$choice" =~ [aA] ]]; then
    echo "A"
elif [[ "$choice" =~ [bB] ]]; then
    echo "B"
elif [[ "$choice" =~ [cC] ]]; then
    echo "C"
elif [[ "$choice" =~ [dD] ]]; then
    echo "D"
else
    echo "Thats not a choice :("
fi
echo "=============================================="