#!/bin/bash
#This is a script to hash or compare two folders to test build viability.
echo "==================================================="

meridiem=$(date | awk '{print $5}')
if [[ "$meridiem" == AM ]]; then
	echo "Good Morning :)"
else
	echo "Good Afternoon :)"
fi

echo "==="

drive=$(journalctl --since '1m ago' | grep -Eo "sd\w" | awk -v RS=\n '{print $NF}')
if [[ -n $drive ]]; then
	echo "Detecting drive as $drive; checking hashes..."
	echo "================"
else
	drive=$(lsblk | grep RHEL* | grep -Eo "sd\w")
	umount /run/media/nerd/RHEL*
	rm -rf /run/media/nerd/RHEL*
	echo "Detecting drive as $drive; checking hashes..."
	echo "================"
fi

mkdir "/var/iso/hashing"
ddsmiso=$(find / -type f -name ddsm-esxi.iso 2>/dev/null)
mount -o ro,loop $ddsmiso "/var/iso/hashing"
cd "/var/iso/hashing"
isobuild=$((find ddsm-esxi -type f -print0 | sort -z | xargs -0 sha1sum; find ddsm-esxi \( -type f -o -type d \) -print0 | sort -z | xargs -0 stat -c '%n %a') | sha1sum)
echo "This is the control: $isobuild"
echo "---"

mkdir "/run/media/nerd/hashing"
mount -o ro /dev/$drive'1' /run/media/nerd/hashing
cd "/run/media/nerd/hashing"
drivebuild=$((find ddsm-esxi -type f -print0 | sort -z | xargs -0 sha1sum; find ddsm-esxi \( -type f -o -type d \) -print0 | sort -z | xargs -0 stat -c '%n %a') | sha1sum)
echo "This is your built drive: $drivebuild"
echo "==="

cd /
if [[ $isobuild == $drivebuild ]]; then
	echo "Your builds MATCH!"
	echo "========================================="
	echo "Press any key to return to launcher..."
	read -rsn1
	
	umount "/var/iso/hashing"
	rm -rf "/var/iso/hashing"
	umount "/run/media/nerd/hashing"
	rm -rf "/run/media/nerd/hashing"
else
	echo "Your builds DO NOT MATCH!"
	echo "========================================="
	echo "Press any key to view the differences between the builds..."
	read -rsn1
	
	clear
	diff -qrN "/var/iso/hashing/ddsm-esxi" /run/media/nerd/hashing/ddsm-esxi
	echo "========================================="
	echo "Press any key to return to launcher..."
	read -rsn1
	
	umount "/var/iso/hashing"
	rm -rf "/var/iso/hashing"
	umount "/run/media/nerd/hashing"
	rm -rf "/run/media/nerd/hashing"
fi