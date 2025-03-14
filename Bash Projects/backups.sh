#!/bin/bash

# BACKUP DIRECTORY (include "/" at the end of the absolute path)
dest_directory=""

# BACKUP
yes | cp /etc/hosts $dest_directory
yes | cp -r /etc/NetworkManager/system-connections/ $dest_directory
yes | cp -r /srv/REPO/logs/ $dest_directory
yes | cp -r /srv/scripts/ $dest_directory
