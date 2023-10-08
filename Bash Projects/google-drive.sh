#!/bin/bash

#This script will list out all files and download one at a time from a public Google Drive repo.

wget_D=$(apt --installed list 2>/dev/null | egrep "wget")
jq_D=$(apt --installed list 2>/dev/null | egrep "jq")
key='' #Put an API key you can create at Google Cloud' console for Google Drive API here.
folder='' #This is the folder ID not the whole copied link.
#This establishes some variables.

#------------------------------------------
clear
if [[ -z "$folder" ]]; then
        read -p "Please paste a public Google Drive folder link: " link
        folder=$(echo $link | awk -F"/" '{print $NF}' | awk -F"?" '{print $1}')

fi
#This will check if folder is hardcoded and if not, will prompt for a link.

#------------------------------------------
clear
if [[ -z "$key" ]]; then
        echo "You're missing an API key"
        echo "Open me up and put one in between the single quotes next to the 'key' variable."
        return 1

fi
#This will check if you have an API key in the variable.

#------------------------------------------
if [[ -z "$wget_D" ]]; then
        echo "============================================================================="
        echo "Installing dependency wget..."
        apt update > /dev/null 2>&1
        apt -y install wget > /dev/null 2>&1

fi

if [[ -z "$jq_D" ]]; then
        echo "============================================================================="
        echo "Installing dependency jq..."
        apt update > /dev/null 2>&1
        apt -y install jq > /dev/null 2>&1

fi
#This will download the dependencies for this script.

#------------------------------------------
clear
echo "=============================================================================="
file_list=$(wget -qO- "https://www.googleapis.com/drive/v3/files?q='$folder'+in+parents&key=$key")
echo $file_list | jq '.files[] | {name} | join(" ")'
echo "=============================================================================="
read -p "Would you like to download a file (y/n): " choice
#This lists out files in the repo and presents a choice to download.

#------------------------------------------
while [[ $choice =~ y|Y ]]; do
        clear
        echo "=============================================================================="
        echo $file_list | jq '.files[] | {name} | join(" ")'
        echo "=============================================================================="
        read -p "Please enter the name of the file you want to download (case insensitive): " file
        clear
        #Reloads list of files for while loop and gets input from the user on what file to download.

        #----------------------------------------
        echo "=============================================================================="
        echo $file_list | jq -r --arg file "$file" '[.files[] | select(.name|test($file))][0]'
        echo "=============================================================================="
        read -p "Please enter the name again to confirm or change your choice (case insensitive): " file
        clear
        #Lists specific info for the file selected and confirms choice with user.

        #----------------------------------------
        echo "=============================================================================="
        echo $file_list | jq -r --arg file "$file" '[.files[] | select(.name|test($file))][0]'
        echo "=============================================================================="
        file_id=$(echo $file_list | jq -r --arg file "$file" '[.files[] | select(.name|test($file))][0] | .id')
        file_name=$(echo $file_list | jq -r --arg file "$file" '[.files[] | select(.name|test($file))][0] | .name')
        wget "https://www.googleapis.com/drive/v3/files/$file_id?alt=media&key=$key" -O $file_name
        echo "=============================================================================="
        #Lists specific info for file selected and stores the file id and name to download the file.

        #----------------------------------------
        read -p "Would you like to download another file (y/n): " choice

done
#This while loop keeps you engaged in choice of downloading multiple files.

#------------------------------------------
clear
echo "============================================================================="
echo "Dependencies installed by script or already installed are:
wget - HTTP/S Utility
jq - JSON Parsing"
echo "============================================================================="
echo "You may want to 'apt remove *' these files manually as other packages may be affected if they were not installed by this script."

echo "Bye :)"