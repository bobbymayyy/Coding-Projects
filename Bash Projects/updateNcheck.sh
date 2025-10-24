#!/usr/bin/env bash
#This is a script to update some drives you select and then validate build of the drive against the update used.
clear
set -euo pipefail
IFS=$'\n\t'

# Variables ================
# Specify if we are bandwidth-conscious
bandwidth_conscious="yes"

# Specify the overall release file - REPLACE THE ASTERISK WITH RELATIVE PATH - will be ddsm-esxi (or the hash_folder if they change it) and on
iso_release_file="*"
img_release_file="*"

# Specify the tools release file - REPLACE THE ASTERISK WITH RELATIVE PATH - will be ddsm-esxi (or the hash_folder if they change it) and on
iso_tools_file="*"
img_tools_file="*"

# Specify the path to look for ISOs
isos_path="/srv/REPO/isos"

# Specify the log file we will report to
log_path="/srv/REPO/logs"
log_file="/srv/REPO/logs/burnNcheck.log"

# Specify the folder to be hashed - RELATIVE PATH
iso_hash_folder="*"
img_hash_folder="*"

# Specify the user-space user the script is running on - NOT ROOT
user="*"

# Functions ================
# Function to clean up ROM and RAM
clean_up() {
    umount /srv/iso/*
    umount /srv/drives/*
    umount /run/media/$user/*
    rm -rf "/srv/iso"
    rm -rf "/srv/drives"
}

# Function to list drives safely
list_drives() {
    lsblk -dno NAME,TRAN,SIZE,TYPE | awk '$2 == "usb"' | while read -r name tran size type; do
        drive="/dev/$name"
        echo "$drive $size"
    done
}

# Function to generate a dialog checklist for drive selection
select_drives() {
    drives=$(list_drives)
    options=()
    while read -r drive size; do
        options+=("$drive" "$size" "off")
    done <<< "$drives"
    selected_drives=$(dialog --clear --stdout \
        --checklist "Select drives to burn image:" 15 50 10 \
        "${options[@]}")
    echo "$selected_drives"
}

# Function to list ISO files with their sizes
list_isos() {
    find "$isos_path" -maxdepth 1 -type f -name "*.i*" -exec du -h -- "{}" + | sort -k2,2r -t ' ' | awk '{print $1,$2}' | awk -F'/' '{print $1,$NF}'
}

# Function to generate a dialog checklist for ISO selection
select_iso() {
    isos=$(list_isos)
    options=()
    while read -r size name; do
        options+=("$name" "$size")
    done <<< "$isos"
    selected_iso=$(dialog --clear --stdout \
        --menu "Select an ISO file:" 15 50 10 \
        "${options[@]}")
    echo "$selected_iso"
}

# Function to disable USB ports used by storage devices except the one associated with the current drive
disable_other_storage_ports() {
    local current_drive=$1
    echo "Processing drive: $current_drive"
    sysfs_path=$(udevadm info -q path -n "$current_drive")
    if [[ -z "$sysfs_path" ]]; then
        echo "Failed to find sysfs path for $current_drive."
        exit 1
    fi
    active_port=$(basename "$sysfs_path")
    echo "Keeping USB port active: $active_port"
    storage_ports=$(ls /sys/bus/usb/devices/*/block/* 2>/dev/null | awk -F'/' '{print $(NF-3)}')
    for port in $storage_ports; do
        if [[ "$port" != "$active_port" ]]; then
            echo "Disabling USB storage port: $port"
            echo 'suspend' | sudo tee /sys/bus/usb/devices/$port/power/level > /dev/null
        fi
    done
}

# Function to re-enable all USB storage ports
enable_all_storage_ports() {
    echo "Re-enabling all USB storage ports..."
    storage_ports=$(ls /sys/bus/usb/devices/*/block/* 2>/dev/null | awk -F'/' '{print $(NF-3)}')
    for port in $storage_ports; do
        echo "Enabling USB storage port: $port"
        echo 'on' | sudo tee /sys/bus/usb/devices/$port/power/level > /dev/null
    done
    echo "All USB storage ports re-enabled."
}

# Interrupt function to properly clean after interrupt
interrupt() {
    echo "Cleaning up before exit..."
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    umount /srv/iso/*
    umount /srv/drives/*
    clean_up
    enable_all_storage_ports
    if [[ -e "$log_file" ]]; then
        echo "$(date) ////////////////////////////////////////////// INTERRUPT" >> "$log_file"
    else
        mkdir -p "$log_path" && touch "$log_file"
        echo "$(date) ////////////////////////////////////////////// INTERRUPT" >> "$log_file"
    fi
    exit 1
}
# Trap SIGINT (CTRL+C) and call cleanup
trap interrupt SIGINT

# Function to burn an image to multiple drives concurrently
burn_image() {
    local image_path="$1"
    shift
    local drives=("$@")
    echo "===================================="
    echo "Writing image to the following drives: ${drives[*]}"
    echo "-----------------------"
    if [[ "$bandwidth_conscious" == "yes" ]]; then
        for drive in "${drives[@]}"; do
            (
                disable_other_storage_ports "$drive"
                dd if="$image_path" of="$drive" bs=8M status=progress conv=fsync
                enable_all_storage_ports "$drive"
            )
        done
    elif [[ "$bandwidth_conscious" == "no" ]]; then
        for drive in "${drives[@]}"; do
            (
                dd if="$image_path" of="$drive" bs=8M status=progress conv=fsync
            ) &
        done
    fi
    wait
    echo "-----------------------"
    echo "All drives have been written."
}

verify_image-core() {
    drive_name=$(echo $drive | grep -Eo "sd\w")
    mkdir -p "/srv/drives/$drive_name/hashing"
    umount $drive'1' 2>/dev/null
    mount -o ro $drive'1' "/srv/drives/$drive_name/hashing"
    cd "/srv/drives/$drive_name/hashing"
    drive_build=$(find "$hash_folder" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum)
    cd /
    umount "/srv/drives/$drive_name/hashing"
    rm -rf "/srv/drives/$drive_name/hashing"
    echo "$drive_name: $drive_build"
    echo "----"
    if [[ "$isobuild" == "$drive_build" ]]; then
        echo "$drive_name: OK"
    else
        echo "$drive_name: NOT OK"
    fi
}

# Function to verify the image was burnt to multiple drives successfully
verify_image() {
    local image_path="$1"
    shift
    local drives=("$@")
    echo "===================================="
    echo "Verifying the following drives: ${drives[*]}"
    echo "-----------------------"
    mkdir -p "/srv/iso/hashing"
    mount -o ro,loop "$image_path" "/srv/iso/hashing"
    cd "/srv/iso/hashing"
    release=$(cat $release_file)
    tools=$(cat $tools_file) 
    isobuild=$(find "$hash_folder" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum)
    cd /
    echo "Control: $isobuild"
    echo "--------------"
    if [[ "$bandwidth_conscious" == "yes" ]]; then
        for drive in "${drives[@]}"; do
            (
                disable_other_storage_ports "$drive"
                verify_image-core
                enable_all_storage_ports "$drive"
            )
        done
    elif [[ "$bandwidth_conscious" == "no" ]]; then
        for drive in "${drives[@]}"; do
            (
                verify_image-core
            ) &
        done
    fi
    wait
    echo "-----------------------"
    echo "All drives have been verified."
}

# Function to log start time of burnNcheck
start_time() {
    if [[ -e "$log_file" ]]; then
        echo "$(date) ---------------------------------------------- Start Time" >> "$log_file"
    else
        mkdir -p "$log_path" && touch "$log_file"
        echo "$(date) ---------------------------------------------- Start Time" >> "$log_file"
    fi
}

# Function to log more information about the burnNcheck
log_action() {
    if [[ -e "$log_file" ]]; then
        echo "$(date) - "$release" - "$tools" - Control: "$isobuild" - End Time" >> "$log_file"
    else
        mkdir -p "$log_path" && touch "$log_file"
        echo "$(date) - "$release" - "$tools" - Control: "$isobuild" - End Time" >> "$log_file"
    fi
}

# Main =================================
# Pack in
clean_up

# Select drives and verify selection
selecteddrives=$(select_drives)
if [ -z "$selecteddrives" ]; then
    echo "No drives selected. Exiting."
    exit 0
fi

# Convert selected drives to an array
selected_drives=($selecteddrives)

# Select ISO and verify selection
selectediso=$(select_iso)
if [ -z "$selectediso" ]; then
    echo "No ISO selected. Exiting."
    exit 0
fi
selectediso=$(echo "$isos_path"'/'"$selectediso")

# burnNcheck the image with the selected drives
start_time
burn_image "$selectediso" "${selected_drives[@]}"
verify_image "$selectediso" "${selected_drives[@]}"
log_action

# Wait to return back to launcher
echo "===================================="
echo "Press any key to return to launcher..."
read -rsn1

# Pack out
clean_up
