#!/bin/bash
#This is a script to burn an ISO file to multiple physical drives at once, then hash and compare the mounted ISO with the built drives to test build viability.
clear

# Cursory ================

# Specify if we are bandwidth-conscious
bandwidth_conscious="yes"

# Specify the overall release file
release_file=""

# Specify the tools release file
tools_file=""

# Specify the log file we will report to
log_path="/srv/REPO/logs/"
log_file="/srv/REPO/logs/burnNcheck.log"

# Specify the ISO to use for easier updating in the future
iso_selection="ddsm-esxi*.iso"

# Specify the folder to be hashed - RELATIVE PATH
hash_folder="ddsm-esxi"

# Find the ISO to burn
iso_path=$(find / -type f -name "$iso_selection" 2>/dev/null)

# Functions ================

# Function to clean up ROM and RAM
clean_up() {
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

# Function to generate a dialog checklist
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

# Function to burn an image to multiple drives concurrently
burn_image() {
    local image_path="$1"
    shift
    local drives=("$@")
    if [[ "$bandwidth_conscious" == "yes" ]]; then
        local commands=""
        local concurrency=""

    elif [[ "$bandwidth_conscious" == "no" ]]; then
        local commands=""
        local concurrency=" &"

    echo "===================================="
    echo "Writing image to the following drives: ${drives[*]}"
    echo "-----------------------"
    
    for drive in "${drives[@]}"; do
        (
            "$commands"
            dd if="$image_path" of="$drive" bs=8M status=progress conv=fsync
        )"$concurrency"
    done

    wait
    echo "-----------------------"
    echo "All drives have been written."
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
    isobuild=$(find "$hash_folder" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum)
    cd /
    umount "/srv/iso/hashing"
    rm -rf "/srv/iso/hashing"
    echo "Control: $isobuild"
    echo "--------------"

    for drive in "${drives[@]}"; do
        (
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
        ) &
    done

    wait
    echo "-----------------------"
    echo "All drives have been verified."
}

# Function to log simple information about the running of this script
log_action() {
    if [[ -e "$log_file" ]]; then
        echo "$(date) - Release: $(cat "$release_file") - Tools: $(cat "$tools_file") - Control: "$isobuild"" >> "$log_file"
    else
        mkdir -p "$log_path" && touch "$log_file"
        echo "$(date) - Release: $(cat "$release_file") - Tools: $(cat "$tools_file") - Control: "$isobuild"" >> "$log_file"
    fi
}

# Main ==================================

# Pack in
clean_up

# Select drives and verify selection
selected=$(select_drives)
if [ -z "$selected" ]; then
    echo "No drives selected. Exiting."
    exit 0
fi

# Convert selected drives to an array
selected_drives=($selected)

# burnNcheck the image with the selected drives
clear
burn_image "$iso_path" "${selected_drives[@]}"
verify_image "$iso_path" "${selected_drives[@]}"
log_action

# Wait to return back to launcher
echo "===================================="
echo "Press any key to return to launcher..."
read -rsn1

# Pack out
clean_up
