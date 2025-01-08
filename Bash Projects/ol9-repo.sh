#!/bin/bash

username=""

# Deploy DIP repository
mv /etc/yum.repos.d/oracle-epel-ol9.repo /etc/yum.repos.d/oracle-epel-ol9.repo.ark
mv /etc/yum.repos.d/oracle-linux-ol9.repo /etc/yum.repos.d/oracle-linux-ol9.repo.ark
mv /etc/yum.repos.d/uek-ol9.repo /etc/yum.repos.d/uek-ol9.repo.ark
mv /etc/yum.repos.d/virt-ol9.repo /etc/yum.repos.d/virt-ol9.repo.ark
cp -f /run/media/$username/DIP/ol9-repo/dip-ol9.repo /etc/yum.repos.d/dip-ol9.repo

# Clean and update
dnf clean all
dnf upgrade
