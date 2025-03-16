#!/bin/bash

# CURSORY ===========
isos_path="/srv/REPO/isos"

# FUNCTIONS ================

# Function to list ISO files with their sizes
list_isos() {
    find "$isos_path" -maxdepth 1 -type f -name "*.iso" -exec du -h -- "{}" + | sort -r -k2,2r -t ' ' | awk '{print $1,$2}' | awk -F'/' '{print $1,$NF}'
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

# Function to clean everything up once done
clean_up() {
    # UNMOUNT THE ISO ONCE DONE
    umount /var/www/pxe/selected_os
    rm -rf /var/www/pxe/selected_os
    systemctl stop nginx
    systemctl stop dnsmasq
    firewall-cmd --remove-service=dhcp
    firewall-cmd --remove-service=tftp
    firewall-cmd --remove-service=dns
    firewall-cmd --remove-service=http
    firewall-cmd --reload
    clear
}

# MAIN ==================================

# Pack in
clean_up

# Select ISO and verify selection
selectediso=$(select_iso)
if [ -z "$selectediso" ]; then
    echo "No ISO selected. Exiting."
    clean_up
    exit 0
fi
selectediso=$(echo "$isos_path"'/'"$selected_iso")

# ADD SERVICES ON FIREWALL
firewall-cmd --add-service=dhcp
firewall-cmd --add-service=tftp
firewall-cmd --add-service=dns
firewall-cmd --add-service=http
firewall-cmd --reload

# ENABLE SERVICES
# HTTP for media serving
systemctl start nginx
# dnsmasq provides DHCP and TFTP
systemctl start dnsmasq

# MOUNT THE SELECTED ISO FOR HTTP
mkdir -p /var/www/pxe/selected_os
mount -t iso9660 -o ro,loop "$selectediso" /var/www/pxe/selected_os

# SLEEP FOR 2 HOURS
#sleep 2h
dialog --clear --stdout --pause "PXE booting is available for 2 hours...\nIt will not be availble upon exit." 10 50 7200

# Pack out
clean_up
