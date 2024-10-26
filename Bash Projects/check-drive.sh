#!/bin/bash
#This is a script to hash or compare two folders to test build viability.
clear
echo "==================================================="

meridiem=$(date | awk '{print $5}')
if [[ "$meridiem" == AM ]]; then
	echo "Good Morning :)"
else
	echo "Good Afternoon :)"
fi

echo "==="
echo "PLEASE UNPLUG THE FINISHED DRIVE AND PLUG BACK IN!"
echo "==="
echo "Press any key to continue once done..."
read -rsn1

clear
echo "==================================================="

drive=$(journalctl --since '5m ago' | grep -Eo "sd\w" | awk -v RS=\n '{print $NF}')
echo "Detecting drive as $drive; checking hashes..."
echo "================"

mkdir "/var/iso/test"
ddsmiso=$(find / -type f -name ddsm-esxi.iso 2>/dev/null)
mount -o loop $ddsmiso "/var/iso/test"
cd "/var/iso/test"
isobuild=$((find ddsm-esxi -type f -print0 | sort -z | xargs -0 sha1sum; find ddsm-esxi \( -type f -o -type d \) -print0 | sort -z | xargs -0 stat -c '%n %a') | sha1sum)
echo "This is the control: $isobuild"
echo "---"

cd /run/media/nerd/RHEL*
drivebuild=$((find ddsm-esxi -type f -print0 | sort -z | xargs -0 sha1sum; find ddsm-esxi \( -type f -o -type d \) -print0 | sort -z | xargs -0 stat -c '%n %a') | sha1sum)
echo "This is your built drive: $drivebuild"
echo "==="

cd /
if [[ $isobuild == $drivebuild ]]; then
	echo "Your builds MATCH!"
	echo "========================================="
	echo "Press any key to return to launcher..."
	read -rsn1
	
	umount "/var/iso/test"
	rm -rf "/var/iso/test"
	umount /run/media/nerd/RHEL*
	rm -rf /run/media/nerd/RHEL*
else
	echo "Your builds DO NOT MATCH!"
	echo "========================================="
	echo "Press any key to view the differences between the builds..."
	read -rsn1
	
	clear
	diff -qrN "/var/iso/test/ddsm-esxi" /run/media/nerd/RHEL*/ddsm-esxi
	echo "========================================="
	echo "Press any key to return to launcher..."
	read -rsn1
	
	umount "/var/iso/test"
	rm -rf "/var/iso/test"
	umount /run/media/nerd/RHEL*
	rm -rf /run/media/nerd/RHEL*
fi
