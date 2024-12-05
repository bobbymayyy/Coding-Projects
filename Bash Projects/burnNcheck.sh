#!/bin/bash
#This is a script to burn an ISO file to multiple physical drives at once, then hash and compare the mounted ISO with the built drives to test build viability.
clear

# Cursory ================

# Find the ISO to burn
image_iso=$(find / -type f -name ddsm-esxi.iso 2>/dev/null)

# Functions ================

# Function to clean up ROM and RAM
clean_up() {
    umount "/srv/iso/hashing"
    rm -rf "/srv/iso/hashing"
    umount "/srv/drive/hashing"
    rm -rf "/srv/drive/hashing"
}

# Function to list drives safely
list_drives() {
    root_drive=$(findmnt -nro SOURCE / | sed 's/[0-9]*$//')
    boot_drive=$(findmnt -nro SOURCE /boot 2>/dev/null | sed 's/[0-9]*$//')
    swap_drives=$(cat /proc/swaps | awk 'NR>1 {print $1}' | sed 's/[0-9]*$//')

    lsblk -dno NAME,SIZE,TYPE | awk '$3 == "disk"' | while read -r name size type; do
        drive="/dev/$name"
        if [[ "$drive" != "$root_drive" && "$drive" != "$boot_drive" && ! "$swap_drives" =~ "$drive" ]]; then
            echo "$drive $size"
        fi
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

    echo "Writing image to the following drives: ${drives[*]}"
    
    for drive in "${drives[@]}"; do
        (
            dd if="$image_path" of="$drive" bs=10M status=progress conv=fsync
        ) &
    done

    wait
    echo "All drives have been written."
}

# Function to verify the image was burnt to multiple drives successfully
verify_image() {
    local image_path="$1"
    shift
    local drives=("$@")

    echo "Verifying the following drives: ${drives[*]}"

    mkdir "/srv/iso/hashing"
    mount -o ro,loop $image_path "/srv/iso/hashing"
    cd "/srv/iso/hashing"
    isobuild=$(find ddsm-esxi -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum)
    echo "Control: $isobuild"

    for drive in "${drives[@]}"; do
        (
            drive_name=$(echo $drive | grep -Eo "sd\w")
            mkdir "/srv/$drive_name/hashing"
            mount -o ro,loop $drive "/srv/$drive_name/hashing"
            cd "/srv/$drive_name/hashing"
            $drive_namebuild=$(find ddsm-esxi -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum)
            echo "$drive_name: $drive_namebuild"
            if [[ $isobuild == $drive_namebuild ]]; then
                echo "$drive_name: OK"
            else
                echo "$drive_name: NOT OK"
            fi
        ) &
    done

    wait
    echo "All drives have been verified."
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
burn_image "$image_iso" "${selected_drives[@]}"
verify_image "$image_iso" "${selected_drives[@]}"

# Wait to return back to launcher
echo "Press any key to return to launcher..."
read -rsn1

# Pack out
clean_up
