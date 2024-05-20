#!/bin/bash

#This is a dialog "gui" for creating tunnels through Palo Alto CLI configuration changes...
clear
# - The asparagus ||
#                 \/
#==========================#===========================#===========================#
DIALOG=dialog   # - Set dialog variables
DIALOG_TITLE="Welcome to AutoVPN."
DIALOG_ESTABLISH=0
DIALOG_DEMOLISH=1
DIALOG_HELP=2
DIALOG_EDIT=3
DIALOG_ITEM_HELP=4
DIALOG_TIMEOUT=5
DIALOG_ESC=255
SIG_NONE=0
SIG_HUP=1
SIG_INT=2
SIG_QUIT=3
SIG_KILL=9
SIG_TERM=15
# - The meat and potatoes ||
#                         \/
#==========================#===========================#===========================#
backtitle="AutoVPN - A utility for easily creating IPSEC tunnels in Palo Alto"
fw_addr=""          # - Passed to main function
fw_user=""          #             ||
fw_pass=""          #             ||
team_num=""         #             ||
octet=""            #             ||
kit_num=""          #             ||
int_num=""          #             ||
wan_addr=""         #             ||
peer_addr=""        #             ||
psk_key=""          #             \/
pass_cover="" # - Veil the sensitive values -
psk_cover="" # --------------------------------
returncode=0        # - Initialize
defaultitem="FW IP Address:"    # - Set default input field
debugger() {
    echo "--------------------"
    echo "Press any key to continue..."
    read -rsn1
}
remove_zeros() {
    # Convert number to string to handle leading zeros
    local team_num="$1"
    local len="${#team_num}"
    # Remove leading zero
    team_num=$(echo "$team_num" | sed 's/^0*//')
    # Remove trailing zero
    team_num="${team_num%0}"
    # If already mitigated then return otherwise remove all zeroes
    if (( $team_num >= 255 )); then
        team_num="${team_num//0}"
        team_num=$(( team_num >= 255 ? 88 : team_num ))
        echo "$team_num"
    else
        echo "$team_num"
    fi
}
configure_firewall() {
    local fw_addr="$1"
    local fw_user="$2"
    local fw_pass="$3"
    local team_num="$4"
    local octet="$5"
    local kit_num="$6"
    local int_num="$7"
    local wan_addr="$8"
    local peer_addr="$9"
    local psk_key="${10}"
    local commands="${11}"
    local success=0
    local ssh_newkey="Are you sure you want to continue connecting"
    # Define command list
    if [ "$commands" == "deploy" ]; then
        debugger
        expect -c "
            set timeout 90
            spawn ssh -o StrictHostKeyChecking=no $fw_user@$fw_addr
            expect {
                \"$ssh_newkey\" {
                    send \"yes\\r\"
                    exp_continue
                }
                \"assword:\" {
                    send \"$fw_pass\\r\"
                }
                timeout {
                    exit 1
                }
                eof {
                    exit 1
                }
            }
            expect \">\"
            send \"set cli terminal width 500\\r\"
            expect \">\"
            send \"set cli scripting-mode on\\r\"
            expect \">\"
            send \"configure\\r\"
            expect \"#\"
            send \"set network interface tunnel units tunnel.$team_num ip 192.168.$octet.2/24\\r\"
            expect \"#\"
            send \"set network interface tunnel units tunnel.$team_num mtu 1350\\r\"
            expect \"#\"
            send \"set network interface ethernet ethernet1/$int_num layer3 ip $wan_addr/28\\r\"
            expect \"#\"
            send \"set network virtual-router default interface tunnel.$team_num\\r\"
            expect \"#\"
            send \"set zone VPN network layer3 tunnel.$team_num\\r\"
            expect \"#\"
            send \"set network ike crypto-profiles ike-crypto-profiles CPT$team_num hash sha384 dh-group group20 encryption aes-256-cbc lifetime seconds 28800\\r\"
            expect \"#\"
            send \"set network ike crypto-profiles ipsec-crypto-profiles CPT$team_num esp authentication sha256 encryption aes-256-cbc\\r\"
            expect \"#\"
            send \"set network ike crypto-profiles ipsec-crypto-profiles CPT$team_num lifetime seconds 3600\\r\"
            expect \"#\"
            send \"set network ike crypto-profiles ipsec-crypto-profiles CPT$team_num dh-group group20\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num authentication pre-shared-key key $psk_key\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num protocol ikev2 dpd enable yes\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num protocol ikev2 ike-crypto-profile CPT$team_num\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num protocol version ikev2\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num local-address interface ethernet1/$int_num ip $wan_addr/28\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num protocol-common nat-traversal enable no\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num protocol-common fragmentation enable yes\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num peer-address ip $peer_addr\\r\"
            expect \"#\"
            send \"set network ike gateway CPT$team_num local-id id $team_num'cpt@cpb.army.mil' type ufqdn\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num auto-key ike-gateway CPT$team_num\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num auto-key ipsec-crypto-profile CPT$team_num\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num tunnel-monitor enable no\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num tunnel-interface tunnel.$team_num\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num anti-replay yes\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num copy-tos yes\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num disabled no\\r\"
            expect \"#\"
            send \"set network tunnel ipsec CPT$team_num tunnel-monitor destination-ip 192.168.$octet.1 enable yes tunnel-monitor-profile default\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf router-id $wan_addr\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf enable yes\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num enable yes\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num passive no\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num gr-delay 10\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num metric 10\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num priority 1\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num hello-interval 10\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num dead-counts 4\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num retransmit-interval 5\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num transit-delay 1\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf area 0.0.0.$octet interface tunnel.$team_num link-type p2p\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol redist-profile Kit$kit_num action redist\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol redist-profile Kit$kit_num priority 1\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol redist-profile Kit$kit_num filter type connect destination 10.$kit_num.0.0/16\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf export-rules Kit$kit_num new-path-type ext-2\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf enable yes area 0.0.0.$octet type normal\\r\"
            expect \"#\"
            send \"commit\\r\"
            expect \"#\"
            send \"exit\\r\"
            expect \">\"
            send \"exit\\r\"
            close
        "
    elif [ "$commands" == "destroy" ]; then
        expect -c "
            set timeout 90
            spawn ssh -o StrictHostKeyChecking=no $fw_user@$fw_addr
            expect {
                \"$ssh_newkey\" {
                    send \"yes\\r\"
                    exp_continue
                }
                \"assword:\" {
                    send \"$fw_pass\\r\"
                }
                timeout {
                    exit 1
                }
                eof {
                    exit 1
                }
            }
            expect \">\"
            send \"set cli terminal width 500\\r\"
            expect \">\"
            send \"set cli scripting-mode on\\r\"
            expect \">\"
            send \"configure\\r\"
            expect \"#\"
            send \"delete zone VPN network layer3 tunnel.$team_num\\r\"
            expect \"#\"
            send \"delete network tunnel ipsec CPT$team_num\\r\"
            expect \"#\"
            send \"delete network virtual-router default protocol ospf area 0.0.0.$octet\\r\"
            expect \"#\"
            send \"set network virtual-router default protocol ospf enable no\\r\"
            expect \"#\"
            send \"delete network virtual-router default protocol ospf router-id\\r\"
            expect \"#\"
            send \"delete network virtual-router default interface tunnel.$team_num\\r\"
            expect \"#\"
            send \"delete network virtual-router default protocol ospf export-rules Kit$kit_num\\r\"
            expect \"#\"
            send \"delete network virtual-router default protocol redist-profile Kit$kit_num\\r\"
            expect \"#\"
            send \"delete network ike gateway CPT$team_num\\r\"
            expect \"#\"
            send \"delete network ike crypto-profiles ipsec-crypto-profiles CPT$team_num\\r\"
            expect \"#\"
            send \"delete network ike crypto-profiles ike-crypto-profiles CPT$team_num\\r\"
            expect \"#\"
            send \"delete network interface tunnel units tunnel.$team_num\\r\"
            expect \"#\"
            send \"delete network interface ethernet ethernet1/$int_num layer3 ip $wan_addr/28\\r\"
            expect \"#\"
            send \"commit\\r\"
            expect \"#\"
            send \"exit\\r\"
            expect \">\"
            send \"exit\\r\"
            close
        "
    fi
    debugger
    success=$?
    # Check if SSH command was successful
    if [ $? -eq 0 ]; then
        success=true
    else
        success=false
    fi
    return $success
}
while test $returncode != 250   # - Main Menu Loop
do
exec 3>&1
returntext=`$DIALOG --clear --ok-label "Establish" \
            --backtitle "$backtitle" \
            --extra-button \
            --extra-label "Edit" \
            --help-button \
            --help-label "Help" \
            --item-help "$@" \
            --cancel-label "Demolish" \
            --default-button extra \
            --default-item "$defaultitem" \
            --colors \
            --inputmenu "$DIALOG_TITLE" \
20 70 20 \
        "FW IP Address:"        "$fw_addr"      "The IP address of your kit's PA FW" \
        "FW Username:"          "$fw_user"      "The username of your kit's PA FW (can create/apply configuration)" \
        "FW Password:"          "$pass_cover"   "The password to the username you have provided" \
        "Team Number:"          "$team_num"     "Your CPT, team number; ie 401, 154, 03, 600" \
        "Kit Number:"           "$kit_num"      "Your kit, DDS-M number; ie 102, 14, 43, 69" \
        "WAN Interface:"        "$int_num"      "The WAN interface the tunnel starts from; should be Untrust (1/'X')" \
        "WAN IP Address:"       "$wan_addr"     "The IP address you want to give to the WAN interface" \
        "Peer IP Address:"      "$peer_addr"    "The IP address of the Juniper you are creating a tunnel to" \
        "Pre-Shared Key:"       "$psk_cover"    "The shared key decided by makers of this tunnel; must be same on both sides" \
2>&1 1>&3`
returncode=$?
exec 3>&-
    case $returncode in
        $DIALOG_DEMOLISH)
            case $returntext in
                HELP*)
                    "$DIALOG" \
                    --textbox "$0" 0 0
                    ;;
                *)
                    # Check for empty fields and complain
                    if [ -z "$fw_addr" ] || [ -z "$fw_user" ] || [ -z "$fw_pass" ] || [ -z "$team_num" ] || [ -z "$kit_num" ] || [ -z "$int_num" ] || [ -z "$wan_addr" ] || [ -z "$peer_addr" ] || [ -z "$psk_key" ]; then
                        DIALOG_TITLE="Welcome to AutoVPN. \Zb(Please fill in all fields.)\ZB"
                    else
                        commands="demolish"
                        octet=$(remove_zeros "$team_num")
                        configure_firewall "$fw_addr" "$fw_user" "$fw_pass" "$team_num" "$octet" "$kit_num" "$int_num" "$wan_addr" "$peer_addr" "$psk_key" "$commands"
                        if [ "$success" == true ]; then
                            DIALOG_TITLE="\Zb\Z2Welcome to AutoVPN.\ZB\Zn"
                        else
                            DIALOG_TITLE="\Zb\Z1Welcome to AutoVPN.\ZB\Zn"
                        fi
                    fi
                    ;;
            esac
            ;;
        $DIALOG_ESTABLISH)
            case $returntext in
                HELP*)
                    "$DIALOG" \
                    --textbox "$0" 0 0
                    ;;
                *)
                    # Check for empty fields and complain
                    if [ -z "$fw_addr" ] || [ -z "$fw_user" ] || [ -z "$fw_pass" ] || [ -z "$team_num" ] || [ -z "$kit_num" ] || [ -z "$int_num" ] || [ -z "$wan_addr" ] || [ -z "$peer_addr" ] || [ -z "$psk_key" ]; then
                        DIALOG_TITLE="Welcome to AutoVPN. \Zb(Please fill in all fields.)\ZB"
                    else
                        commands="establish"
                        octet=$(remove_zeros "$team_num")
                        configure_firewall "$fw_addr" "$fw_user" "$fw_pass" "$team_num" "$octet" "$kit_num" "$int_num" "$wan_addr" "$peer_addr" "$psk_key" "$commands"
                        if [ "$success" == true ]; then
                            DIALOG_TITLE="\Zb\Z2Welcome to AutoVPN.\ZB\Zn"
                        else
                            DIALOG_TITLE="\Zb\Z1Welcome to AutoVPN.\ZB\Zn"
                        fi
                    fi
                    ;;
            esac
            ;;
        $DIALOG_HELP)
            "$DIALOG" \
            --textbox "$0" 0 0
            ;;
        $DIALOG_EDIT)
            tag=`echo "$returntext" | sed -e 's/^RENAMED //' -e 's/:.*/:/'`
            item=`echo "$returntext" | sed -e 's/^[^:]*:[ ]*//' -e 's/[ ]*$//'`
            case "$tag" in
                'FW IP Address':)
                    fw_addr="$item"
                    ;;
                'FW Username':)
                    fw_user="$item"
                    ;;
                'FW Password':)
                    fw_pass="$item"
                    if [ -n "$fw_pass" ]; then
                        pass_cover="******"
                    else
                        pass_cover=""
                    fi
                    ;;
                'Team Number':)
                    team_num="$item"
                    ;;
                'Kit Number':)
                    kit_num="$item"
                    ;;
                'WAN Interface':)
                    int_num="$item"
                    ;;
                'WAN IP Address':)
                    wan_addr="$item"
                    ;;
                'Peer IP Address':)
                    peer_addr="$item"
                    ;;
                'Pre-Shared Key':)
                    psk_key="$item"
                    if [ -n "$psk_key" ]; then
                        psk_cover="******"
                    else
                        psk_cover=""
                    fi
                    ;;
                *)
                    tag=
                    ;;
            esac
            test -n "$tag" && defaultitem="$tag"
            ;;
        *)
            break
            ;;
    esac
done    # - Main Menu Loop End
clear