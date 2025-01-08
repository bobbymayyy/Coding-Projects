#!/bin/bash
# This script is to de-stig certain aspects to prevent proper functionality

# Fix USB stuff
dnf remove usbguard
sed -i 's/^/#/' "/etc/modprobe.d/usb-storage"
modprobe usb-storage

# Fix idle and lock delay
sed -i '/idle-delay/d' "/etc/dconf/db/local.d/locks/00-security-settings-lock"
sed -i '/lock-delay/d' "/etc/dconf/db/local.d/locks/00-security-settings-lock"
sed -i 's/idle-delay=uint32 900/idle-delay=uint32 0/' "/etc/dconf/db/local.d/00-security-settings"
dconf update

# Restart
init 6

