#!/bin/bash

# ADD SERVICES ON FIREWALL
firewall-cmd --add-service=dhcp
firewall-cmd --add-service=tftp
firewall-cmd --add-service=dns
firewall-cmd --add-service=http
firewall-cmd --reload

# ENABLE SERVICES
# HTTP for media serving
systemctl start httpd
# dnsmasq provides DHCP and TFTP
systemctl start dnsmasq

# MOUNT THE SELECTED ISO FOR HTTP
mkdir -p /var/www/html/pxeboot-media
mount -t iso9660 -o ro,loop $selected_iso /var/www/html/pxeboot-media

# SLEEP FOR 2 HOURS
sleep 2h

# UNMOUNT THE ISO ONCE DONE
umount /var/www/html/pxeboot-media
rm -rf /var/www/html/pxeboot-media

# DISABLE SERVICES
systemctl stop httpd
systemctl stop dnsmasq

# REMOVE SERVICES ON FIREWALL
firewall-cmd --remove-service=dhcp
firewall-cmd --remove-service=tftp
firewall-cmd --remove-service=dns
firewall-cmd --remove-service=http
firewall-cmd --reload
