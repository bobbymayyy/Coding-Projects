#!/bin/bash

debugger() {
    echo "--------------------"
    echo "Press any key to continue..."
    read -rsn1
}
passwordless_laptoplap2prox() {
    clear
    echo "============================================="
    echo "Configuring LAPTOP CONTROL NODE to PROXMOX NODE(s) passwordless authentication..."
    echo "============================================="
    rm -rf /root/.ssh
    ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" #on LAPTOP CONTROL NODE
    for i in ${prox_ips[@]}; do
        sshpass -p $USERPASS ssh -o StrictHostKeyChecking=no root@$i 'rm -rf /root/.ssh'
        sshpass -p $USERPASS ssh-copy-id -i /root/.ssh/id_rsa root@$i #on PROXMOX NODE(s) for LAPTOP CONTROL NODE
        echo "============================================="
        ssh root@$i 'echo "Hello" 1>/dev/null' && echo "Passwordless config for $i from LAPTOP CONTROL NODE successful"
        echo "============================================="
        echo "^ Should say Passwordless config for $i from LAPTOP CONTROL NODE successful ^"
    done
}
passwordless_proxlap2prox() {
    clear
    echo "============================================="
    echo "Configuring PROXMOX CONTROL NODE to PROXMOX WORKER(s) passwordless authentication..."
    echo "============================================="
    rm -rf /root/.ssh
    ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" #on PROXMOX CONTROL NODE
    touch /root/.ssh/known_hosts
    cat /root/.ssh/id_rsa > /root/.ssh/known_hosts
    for i in ${prox_ips[@]}; do
        sshpass -p $USERPASS ssh -o StrictHostKeyChecking=no root@$i 'rm -rf /root/.ssh'
        sshpass -p $USERPASS ssh-copy-id -i /root/.ssh/id_rsa root@$i #on PROXMOX WORKERS(s) for PROXMOX CONTROL NODE
        echo "============================================="
        ssh root@$i 'echo "Hello" 1>/dev/null' && echo "Passwordless config for $i from PROXMOX CONTROL NODE successful"
        echo "============================================="
        echo "^ Should say Passwordless config for $i from PROXMOX CONTROL NODE successful ^"
    done
}
passwordless_laptopproxW2proxM() {
    clear
    echo "============================================="
    echo "Configuring PROXMOX WORKER(s) to PROXMOX MASTER passwordless authentication..."
    echo "============================================="
    for ((i=1; i<"${#prox_ips[@]}"; i++)); do
        ssh root@${prox_ips[$i]} 'ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""'
        ssh root@${prox_ips[$i]} "sshpass -p $USERPASS ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@${prox_ips[0]}"
        echo "============================================="
        ssh root@${prox_ips[$i]} "ssh root@${prox_ips[0]} 'echo "Hello" 1>/dev/null'" && echo "Passwordless config for ${prox_ips[$i]} to PROXMOX MASTER successful"
        echo "============================================="
        echo "^ Should say Passwordless config for ${prox_ips[$i]} to PROXMOX MASTER successful ^"
    done
}
passwordless_proxproxW2proxM() {
    clear
    echo "============================================="
    echo "Configuring PROXMOX WORKER(s) to PROXMOX CONTROL NODE passwordless authentication..."
    echo "============================================="
    for ((i=0; i<"${#prox_ips[@]}"; i++)); do
        ssh root@${prox_ips[$i]} 'ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""'
        ssh root@${prox_ips[$i]} "sshpass -p $USERPASS ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@$prox_control"
        echo "============================================="
        ssh root@${prox_ips[$i]} "ssh root@$prox_control 'echo "Hello" 1>/dev/null'" && echo "Passwordless config for ${prox_ips[$i]} to PROXMOX CONTROL NODE successful"
        echo "============================================="
        echo "^ Should say Passwordless config for ${prox_ips[$i]} to PROXMOX CONTROL NODE successful ^"
    done
}

clear
echo "============================================="
meridiem=$(date | awk '{print $5}')

if [[ "$meridiem" == AM ]]; then
    echo "Good Morning :)"
else
    echo "Good Afternoon :)"
fi

echo "=================="
echo "I am Francee Xercise, your virtual assistant to help deploy Defensive Security infrastructure."
echo "============================================="
echo "Press any key to continue..."
read -rsn1

clear
location=''

while [[ -z "$location" ]]; do
    echo "============================================="
    echo "I would like to get some information to and from you before we start."
    echo "---------------------------------------------"
    echo "I should be plugged into your laptop or the Proxmox node(s) that you have installed."
    echo "/////////////////////////////////////////////////////////////////////////////////////////////////////"
    echo "Laptop                                        |                                       Proxmox Node(s)"
    echo "-----------------------------------------------------------------------------------------------------"
    echo "Plug into Cisco's port 1                               Plug Proxmox management NIC into Cisco port 13"
    echo "Plug Cisco port 13 into Proxmox management NIC  May plug in laptop to Cisco port 1 but must assign IP"
    echo "Ansible will run pointed at Proxmox node(s)                          Ansible will run pointed at self"
    echo "-----------------------------------------------------------------------------------------------------"
    echo "/////////////////////////////////////////////////////////////////////////////////////////////////////"
    echo "POC for this infrastructure is SPC May for any other questions."
    echo "============================================="
    echo "Am I running from your laptop or a Proxmox Node? (l/p)"
    echo "--------------------"
    read location
    echo "============================================="
    echo "What platform/plan are we deploying? NICs must be non-SFP."
    echo "--------------------"
    echo "r830 w/6 NICs (p), r630 w/2 NICs (a), a cluster with the worker having 2 NICs (c), or unknown? (n)"
    echo "--------------------"
    read cluster_platform

    echo "============================================="
    echo "Please insert the password used for root login on Proxmox node(s):"
    echo "--------------------"
    read -r USERPASS

    clear
    echo "============================================="

    if [[ "$location" =~ [lL] ]]; then
        echo "Laptop Control Node"
        echo "--------------------"
        echo "List out IP address(es) of the Proxmox nodes, pressing enter after each one. (CTRL-D when done.)"
        echo "============================================="

        while read line; do
            prox_ips=("${prox_ips[@]}" $line)
        done

        echo "--------------------"
        echo "Putting us on the same subnet and testing connection."
        host_int=$(ip a | grep 'state UP' | awk '{print $2}' | awk -F: '{print $1}')
        echo "============================================="

        for i in $host_int; do
            ip a show $i
        done

        echo "============================================="
        echo "Which of these currently UP interfaces is connected to the same subnet as Proxmox?"
        echo "The name after the number please..."
        echo "--------------------"
        read host_int

        echo "============================================="
        echo "Are we airgapped? (y/n)"
        echo "--------------------"
        read airgap
        echo "============================================="

        echo "One second..."
        oct1=$(echo "${prox_ips[0]}" | awk -F. '{print $1}')
        oct2=$(echo "${prox_ips[0]}" | awk -F. '{print $2}')
        oct3=$(echo "${prox_ips[0]}" | awk -F. '{print $3}')
        ip addr flush dev $host_int
        ip addr add $oct1.$oct2.$oct3.68/24 dev $host_int
        
        if [[ "$airgap" =~ [nN] ]]; then
            echo "Adding default route since we are not airgapped..."

            for i in {1,2,254}; do
                route add default gw $oct1.$oct2.$oct3.$i dev $host_int
                google_test=$(ping -c 1 8.8.8.8 | grep 'bytes from' &)
                
                if [[ -n "$google_test" ]]; then
                    break
                else
                    route del default gw $oct1.$oct2.$oct3.$i dev $host_int
                fi
            done
        
        else
            echo "No default route needed since we are airgapped..."
            google_test='1'
        fi

        sleep 5
        
        for i in "${prox_ips[@]}"; do
            test=$(ping -c 1 $i | grep 'bytes from' &)
        done

        if [[ -n "$test" && -n "$google_test" ]]; then
            clear
            echo "============================================="
            echo "Successful connection(s)."
            echo "============================================="
            echo "Moving on..."
        else
            clear
            echo "============================================="
            echo "Failed connection(s)."
            echo "============================================="
            echo "Attempt to identify problems in DHCP or routing and re-run when ready."
            exit
        fi

        apt=$(which apt 2>/dev/null)
        dnf=$(which dnf 2>/dev/null)

        if [[ "$airgap" =~ [yY] ]]; then
            if [[ -n $apt ]]; then
                echo "I see you are using a Debian based distribution of Linux..."
                echo "Installing Ansible and its dependencies needed for this exercise..."
                dpkg --force-depends -i ./packages/debs/ansible/*.deb #dpkg -i ./packages/debs/*/*.deb
                dpkg --force-depends -i ./packages/debs/openvswitch-proxmoxer-sshpass/*.deb
            elif [[ -n $dnf ]]; then
                echo "I see you are using a Red-Hat based distribution of Linux..."
                echo "Installing Ansible and its dependencies needed for this exercise..."
                dnf -y install --disablerepo=* ./packages/rpms/*/*.rpm
            else
                echo "You do not have apt or dnf as a package manager, so I can not extrapolate how to install the .deb or .rpm files for Ansible."
                echo "They are needed to move on with Laptop install, or you can re-run and install on the Proxmox."
                exit
            fi
        else
            if [[ -n $apt ]]; then
                echo "I see you are using a Debian based distribution of Linux..."
                echo "Installing Ansible and its dependencies needed for this exercise..."
                apt -y update > /dev/null 2>&1
                apt -y install ansible > /dev/null 2>&1
                apt -y install sshpass > /dev/null 2>&1
            elif [[ -n $dnf ]]; then
                echo "I see you are using a Red-Hat based distribution of Linux..."
                echo "Installing Ansible and its dependencies needed for this exercise..."
                dnf -y update > /dev/null 2>&1
                dnf -y install ansible > /dev/null 2>&1
                dnf -y install sshpass > /dev/null 2>&1
            else
                echo "You do not have apt or dnf as a package manager, so I can not extrapolate how to install the .deb or .rpm files for Ansible."
                echo "They are needed to move on with Laptop install, or you can re-run and install on the Proxmox."
                exit
            fi
        fi

        passwordless_laptoplap2prox

        for i in ${prox_ips[@]}; do
            ssh root@$i 'mkdir /root/ansible'
            ssh root@$i 'mkdir /root/openvswitch-proxmoxer-sshpass'
            scp -r ./packages/debs/ansible root@$i:/root
            scp -r ./packages/debs/openvswitch-proxmoxer-sshpass root@$i:/root
            ssh root@$i 'dpkg --force-depends -i ./ansible/*.deb'
            ssh root@$i 'dpkg --force-depends -i ./openvswitch-proxmoxer-sshpass/*.deb' #dpkg -i *.deb
        done
        
        if [[ "${#prox_ips[@]}" -gt 1 ]]; then
            passwordless_laptopproxW2proxM
            clear
            echo "============================================="
            echo "Creating Proxmox cluster..."
            echo "============================================="
            ssh root@${prox_ips[0]} 'pvecm create PROXCLUSTER'
            echo "============================================="
            echo "Waiting for cluster to fully initialize..."
            sleep 60

            clear
            for ((i=1; i<"${#prox_ips[@]}"; i++)); do
                echo "============================================="
                echo "Trying to add ${prox_ips[$i]} to the cluster..."
                echo "============================================="
                ssh root@${prox_ips[$i]} "printf '$USERPASS\nyes\n' | pvecm add ${prox_ips[0]} -force true" #backwards issue FIXED
            done

            clear
            echo "============================================="
            echo "You have created a Proxmox cluster..."
            ssh root@${prox_ips[0]} 'pvecm status'
            echo "============================================="
            IFS=$'\n';c_ints=($(ssh root@${prox_ips[1]} 'ip a | grep -v "master vmbr0" | grep "state"' | awk '{print $2}' | awk -F: '{print $1}' | grep -v 'lo' | grep -v 'vmbr' | grep -v 'ovs-system' | grep -v 'tap' | grep -v 'fw'));IFS=' '
        else
            clear
            echo "============================================="
            echo "No Proxmox cluster needed, you only have one node."
            echo "============================================="
            IFS=$'\n';ints=($(ssh root@${prox_ips[0]} 'ip a | grep -v "master vmbr0" | grep "state"' | awk '{print $2}' | awk -F: '{print $1}' | grep -v 'lo' | grep -v 'vmbr' | grep -v 'ovs-system' | grep -v 'tap' | grep -v 'fw'));IFS=' '
        fi

        eth_ints=()
        for i in "${ints[@]}"; do
            non_fibre=$(ssh root@${prox_ips[0]} "ethtool $i | grep 'Supported ports:'" | awk '{print $4}')
            if [[ "$non_fibre" =~ "TP" ]]; then
                eth_ints=("${eth_ints[@]}" $i)
            fi
        done

        inv_check=$(cat ./ansible/inventory.cfg)
        if [[ -z "$inv_check" ]]; then
            printf "%s\n" '[all:vars]' 'ansible_user=root' 'ansible_password='$USERPASS 'p_vmbr_ints='"${eth_ints[*]}" 'a_vmbr1_int='${eth_ints[0]} 'c_vmbr1_int='${c_ints[0]}  '[proxmox]' ${prox_ips[@]}  '[prox_master]' ${prox_ips[0]}  '[prox_workers]' ${prox_ips[@]:1} >> ./ansible/inventory.cfg
        else
            echo '' > ./ansible/inventory.cfg
            printf "%s\n" '[all:vars]' 'ansible_user=root' 'ansible_password='$USERPASS 'p_vmbr_ints='"${eth_ints[*]}" 'a_vmbr1_int='${eth_ints[0]} 'c_vmbr1_int='${c_ints[0]}  '[proxmox]' ${prox_ips[@]}  '[prox_master]' ${prox_ips[0]}  '[prox_workers]' ${prox_ips[@]:1} >> ./ansible/inventory.cfg
        fi
        
        USERPASS=''
        clear
        echo "============================================="
        echo "Is this a test? (y/n)"
        echo "--------------------"
        read testing
        echo "============================================="
        echo "Waiting 30 seconds to let Proxmox settle itself..."
        echo "============================================="
        echo "Check your hardware NICs to find what port(s) ingestion will be setup on, blinking for 30 seconds..."
        echo "============================================="
        if [[ "$cluster_platform" =~ [pP] ]]; then
            for i in ${eth_ints[@]}; do
                ssh root@${prox_ips[0]} "ethtool -p $i 5"
            done
        elif [[ "$cluster_platform" =~ [aA] ]]; then
            ssh root@${prox_ips[0]} "ethtool -p ${eth_ints[0]} 30"
        elif [[ "$cluster_platform" =~ [cC] ]]; then
            ssh root@${prox_ips[1]} "ethtool -p ${c_ints[0]} 30"
        else
            echo "============================================="
            echo "Cannot blink, not able to extrapolate ingestion..."
            echo "============================================="
        fi
        

        clear
        echo "============================================="
        echo "We are going to start the Ansible now."
        echo "============================================="

        if [[ "$testing" =~ [yY] ]]; then
            ansible_check='--check'
        else
            ansible_check=''
        fi

        cd ./ansible
        ansible-playbook $ansible_check playbooks/01_configure_proxmox.yml

        ansible-playbook $ansible_check playbooks/11_deploy_opnsense.yml

        ansible-playbook $ansible_check playbooks/12_deploy_c2.yml

        if [[ "$cluster_platform" =~ [pP] ]]; then
            ansible-playbook $ansible_check playbooks/13_deploy_securityonion.yml
        elif [[ "$cluster_platform" =~ [aA] ]]; then
            ansible-playbook $ansible_check playbooks/132_deploy_securityonion.yml
        elif [[ "$cluster_platform" =~ [cC] ]]; then
            ansible-playbook $ansible_check playbooks/133_deploy_securityonion.yml
        else
            echo "============================================="
            echo "I have not deployed Security Onion as I do not know what kind of cluster platform we are working with."
            echo "============================================="
        fi

: '
        ansible-playbook $ansible_check playbooks/91_destroy_securityonion.yml

        ansible-playbook $ansible_check playbooks/92_destroy_c2.yml

        ansible-playbook $ansible_check playbooks/93_destroy_opnsense.yml
'
        cd ..
        echo '' > ./ansible/inventory.cfg
        echo "/////////////////////////////////////////////"
        echo "Goodbye :)"

    elif [[ "$location" =~ [pP] ]]; then
        echo "Proxmox Control Node"
        echo "--------------------"
        echo "List out IP address(es) of other Proxmox node(s), pressing enter after each one. (CTRL-D when done.)"
        echo "============================================="

        while read line; do
            prox_ips=("${prox_ips[@]}" $line)
        done
        
        prox_control=$(ip a | grep vmbr0 | grep inet | awk '{print $2}' | awk -F/ '{print $1}')
        if [[ -n "${prox_ips[@]}" ]]; then
            clear
            echo "============================================="
            echo "Putting us on the same subnet and testing connection."
            host_int=$(ip a | grep 'state UP' | awk '{print $2}' | awk -F: '{print $1}')
            echo "============================================="

            for i in $host_int; do
                ip a show $i
            done

            echo "============================================="
            echo "Which of these currently UP interfaces is connected to the same subnet as other Proxmox node(s)?"
            echo "The name after the number please..."
            echo "--------------------"
            read host_int

            echo "============================================="
            echo "Are we airgapped? (y/n)"
            echo "--------------------"
            read airgap
            echo "============================================="

            echo "One second..."

            oct1=$(echo "${prox_ips[0]}" | awk -F. '{print $1}')
            oct2=$(echo "${prox_ips[0]}" | awk -F. '{print $2}')
            oct3=$(echo "${prox_ips[0]}" | awk -F. '{print $3}')
            ip addr flush dev $host_int
            ip addr add $oct1.$oct2.$oct3.68/24 dev $host_int

            if [[ "$airgap" =~ [nN] ]]; then
                echo "Adding default route since we are not airgapped..."

                for i in {1,2,254}; do
                    route add default gw $oct1.$oct2.$oct3.$i dev $host_int
                    google_test=$(ping -c 1 8.8.8.8 | grep 'bytes from' &)

                    if [[ -n "$google_test" ]]; then
                        break
                    else
                        route del default gw $oct1.$oct2.$oct3.$i dev $host_int
                    fi
                done

            else
                echo "No default route needed since we are airgapped..."
                google_test='1'
            fi

            sleep 5

            for i in "${prox_ips[@]}"; do
                test=$(ping -c 1 $i | grep 'bytes from' &)
            done

            if [[ -n "$test" && -n "$google_test" ]]; then
                clear
                echo "============================================="
                echo "Successful connection(s)."
                echo "============================================="
                echo "Moving on..."
            else
                clear
                echo "============================================="
                echo "Failed connection(s)."
                echo "============================================="
                echo "Attempt to identify problems in DHCP or routing and re-run when ready."
                exit
            fi
        else
            echo "Are we airgapped? (y/n)"
            echo "--------------------"
            read airgap
            echo "============================================="
            echo "One second..."

            if [[ "$airgap" =~ [nN] ]]; then
                echo "Testing connection to Google"
                google_test=$(ping -c 3 8.8.8.8 | grep 'bytes from' &)
            else
                echo "No default route needed since we are airgapped..."
                google_test='1'
            fi

            sleep 5

            test='1'

            if [[ -n "$test" && -n "$google_test" ]]; then
                clear
                echo "============================================="
                echo "Successful connection(s)."
                echo "============================================="
                echo "Moving on..."
            else
                clear
                echo "============================================="
                echo "Failed connection(s)."
                echo "============================================="
                echo "Attempt to identify problems in DHCP or routing and re-run when ready."
                exit
            fi
        fi

        if [[ "$airgap" =~ [yY] ]]; then
            echo "Installing Ansible and its dependencies needed for this exercise..."
            dpkg --force-depends -i ./packages/debs/ansible/*.deb #dpkg -i ./packages/debs/*/*.deb
            dpkg --force-depends -i ./packages/debs/openvswitch-proxmoxer-sshpass/*.deb
        else
            echo "Installing Ansible and its dependencies needed for this exercise..."
            apt -y update > /dev/null 2>&1
            apt -y install ansible > /dev/null 2>&1
            apt -y install sshpass > /dev/null 2>&1
        fi

        if [[ -n "${prox_ips[@]}" ]]; then
            passwordless_proxlap2prox

            for i in ${prox_ips[@]}; do
                ssh root@$i 'mkdir /root/ansible'
                ssh root@$i 'mkdir /root/openvswitch-proxmoxer-sshpass'
                scp -r ./packages/debs/ansible root@$i:/root
                scp -r ./packages/debs/openvswitch-proxmoxer-sshpass root@$i:/root
                ssh root@$i 'dpkg --force-depends -i ./ansible/*.deb'
                ssh root@$i 'dpkg --force-depends -i ./openvswitch-proxmoxer-sshpass/*.deb' #dpkg -i *.deb
            done
            passwordless_proxproxW2proxM
            clear
            echo "============================================="
            echo "Creating Proxmox cluster..."
            echo "============================================="
            pvecm create PROXCLUSTER
            echo "============================================="
            echo "Waiting for cluster to fully initialize..."
            sleep 60

            clear
            for ((i=0; i<"${#prox_ips[@]}"; i++)); do
                echo "============================================="
                echo "Trying to add ${prox_ips[$i]} to the cluster..."
                echo "============================================="
                ssh root@${prox_ips[$i]} "printf '$USERPASS\nyes\n' | pvecm add $prox_control -force true" #backwards issue FIXED
            done

            clear
            echo "============================================="
            echo "You have created a Proxmox cluster..."
            pvecm status
            echo "============================================="
            IFS=$'\n';c_ints=($(ssh root@${prox_ips[0]} 'ip a | grep -v "master vmbr0" | grep "state"' | awk '{print $2}' | awk -F: '{print $1}' | grep -v 'lo' | grep -v 'vmbr' | grep -v 'ovs-system' | grep -v 'tap' | grep -v 'fw'));IFS=' '
        else
            clear
            echo "============================================="
            echo "No Proxmox cluster needed, you only have one node."
            echo "============================================="
            rm -rf /root/.ssh
            ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" #on PROXMOX CONTROL NODE
            touch /root/.ssh/known_hosts
            cat /root/.ssh/id_rsa > /root/.ssh/known_hosts
            IFS=$'\n';ints=($(ip a | grep -v 'master vmbr0' | grep 'state' | awk '{print $2}' | awk -F: '{print $1}' | grep -v 'lo' | grep -v 'vmbr' | grep -v 'ovs-system' | grep -v 'tap' | grep -v 'fw'));IFS=' '
        fi

        eth_ints=()
        for i in "${ints[@]}"; do
            non_fibre=$(ethtool $i | grep 'Supported ports:' | awk '{print $4}')
            if [[ "$non_fibre" =~ "TP" ]]; then
                eth_ints=("${eth_ints[@]}" $i)
            fi
        done

        inv_check=$(cat ./ansible/inventory.cfg)
        if [[ -z "$inv_check" ]]; then
            printf "%s\n" '[all:vars]' 'ansible_user=root' 'ansible_password='$USERPASS 'p_vmbr_ints='"${eth_ints[*]}" 'a_vmbr1_int='${eth_ints[0]} 'c_vmbr1_int='${c_ints[0]}  '[proxmox]' $HOSTNAME ${prox_ips[@]} '[prox_master]' $HOSTNAME  '[prox_workers]' ${prox_ips[@]} >> ./ansible/inventory.cfg
        else
            echo '' > ./ansible/inventory.cfg
            printf "%s\n" '[all:vars]' 'ansible_user=root' 'ansible_password='$USERPASS 'p_vmbr_ints='"${eth_ints[*]}" 'a_vmbr1_int='${eth_ints[0]} 'c_vmbr1_int='${c_ints[0]}  '[proxmox]' $HOSTNAME ${prox_ips[@]} '[prox_master]' $HOSTNAME  '[prox_workers]' ${prox_ips[@]} >> ./ansible/inventory.cfg
        fi
        
        USERPASS=''
        clear
        echo "============================================="
        echo "Is this a test? (y/n)"
        echo "--------------------"
        read testing
        echo "============================================="
        echo "Waiting 30 seconds to let Proxmox settle itself..."
        echo "============================================="
        echo "Check your hardware NICs to find what port(s) ingestion will be setup on, blinking for 30 seconds..."
        echo "============================================="
        if [[ "$cluster_platform" =~ [pP] ]]; then
            for i in ${eth_ints[@]}; do
                ethtool -p $i 5
            done
        elif [[ "$cluster_platform" =~ [aA] ]]; then
            ethtool -p ${eth_ints[0]} 30
        elif [[ "$cluster_platform" =~ [cC] ]]; then
            ssh root@${prox_ips[0]} "ethtool -p ${c_ints[0]} 30"
        else
            echo "============================================="
            echo "Cannot blink, not able to extrapolate ingestion..."
            echo "============================================="
        fi
        
        clear
        echo "============================================="
        echo "We are going to start the Ansible now."
        echo "============================================="

        if [[ "$testing" =~ [yY] ]]; then
            ansible_check='--check'
        else
            ansible_check=''
        fi

        cd ./ansible
        ansible-playbook $ansible_check playbooks/01_configure_proxmox.yml

        ansible-playbook $ansible_check playbooks/11_deploy_opnsense.yml

        ansible-playbook $ansible_check playbooks/12_deploy_c2.yml

        if [[ "$cluster_platform" =~ [pP] ]]; then
            ansible-playbook $ansible_check playbooks/13_deploy_securityonion.yml
        elif [[ "$cluster_platform" =~ [aA] ]]; then
            ansible-playbook $ansible_check playbooks/132_deploy_securityonion.yml
        elif [[ "$cluster_platform" =~ [cC] ]]; then
            ansible-playbook $ansible_check playbooks/133_deploy_securityonion.yml
        else
            echo "============================================="
            echo "I have not deployed Security Onion as I do not know what kind of cluster platform we are working with."
            echo "============================================="
        fi

: '
        ansible-playbook $ansible_check playbooks/91_destroy_securityonion.yml

        ansible-playbook $ansible_check playbooks/92_destroy_c2.yml

        ansible-playbook $ansible_check playbooks/93_destroy_opnsense.yml
'
        cd ..
        echo '' > ./ansible/inventory.cfg
        echo "/////////////////////////////////////////////"
        echo "Goodbye :)"
    else
        echo "Please specify using l or p, respectively."
        location=''
    fi
done

