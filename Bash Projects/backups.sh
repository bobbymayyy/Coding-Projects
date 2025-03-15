#!/bin/bash

# BACKUP DIRECTORY (include "/" at the end of the absolute path)
dest_directory=""

# BACKUP
mkdir -pZ $dest_directory
yes | cp /etc/hosts $dest_directory
yes | cp -r /etc/NetworkManager/system-connections/ $dest_directory
yes | cp -r /srv/REPO/logs/ $dest_directory
yes | cp -r /srv/scripts/ $dest_directory

echo "Backup created: $(date)" >> $dest_directory'backups.log'
