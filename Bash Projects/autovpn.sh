#!/bin/sh

#This is a dialog "gui" for creating tunnels through Palo Alto CLI configuration changes...

# - The asparagus ||
#                 \/
#==========================#===========================#===========================#
DIALOG=dialog
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_EXTRA=3
DIALOG_ITEM_HELP=4
DIALOG_TIMEOUT=5
DIALOG_ESC=255
#-------------------------
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
fw_addr=""
fw_user=""
fw_pass=""
team_num=""
kit_num=""
int_num=""
wan_addr=""
peer_addr=""
psk_key=""
returncode=0
defaultitem="Firewall IP Address:"
while test $returncode != 1 && test $returncode != 250
do
exec 3>&1
returntext=`$DIALOG --clear --ok-label "Establish" \
            --backtitle "$backtitle" \
            --help-button \
            --help-label "Script" \
            --default-item "$defaultitem" \
            --item-help "$@" \
            --inputmenu "Input the needed values for IPSEC tunnel creation." \
20 60 10 \
        "Firewall IP Address:"  "$fw_addr"      "The IP address of your kit's Palo Alto firewall" \
        "Firewall Username:"    "$fw_user"      "The username of your kit's Palo Alto firewall account that can create and apply configuration" \
        "Firewall Password:"    "$fw_pass"      "The password of your kit's Palo Alto firewall account" \
        "Team Number:"          "$team_num"     "Your CPT number; ie 401, 154, 03, 600" \
        "Kit Number:"           "$kit_num"      "Your kit number; ie 102, 14, 43, 69" \
        "WAN Interface:"        "$int_num"      "The WAN interface you want to apply this tunnel to; should really only be Untrust (1/'X')" \
        "WAN IP Address:"       "$wan_addr"     "The IP address you want to give to the WAN interface for this tunnel" \
        "Peer IP Address:"      "$peer_addr"    "The IP address of the Juniper you are creating a tunnel to" \
        "Pre-Shared Key:"       "$psk_key"      "The shared key that is decided when discussing the need for this tunnel to be created; must be the same on both sides" \
2>&1 1>&3`
returncode=$?
exec 3>&-
    case $returncode in
        $DIALOG_CANCEL)
            "$DIALOG" \
            --clear \
            --backtitle "$backtitle" \
            --yesno "Are you sure you want to quit?" 5 35
            case $? in
                $DIALOG_OK)
                    break
                    ;;
                $DIALOG_CANCEL)
                    returncode=99
                    ;;
            esac
            ;;
        $DIALOG_OK)
            case $returntext in
                HELP*)
                    "$DIALOG" \
                    --textbox "$0" 0 0
                    ;;
                *)
                    "$DIALOG" \
                    --clear \
                    --backtitle "$backtitle" \
                    --msgbox "A progress bar will go here and things will be done..." 10 40
##########             --progressbox           ##############################
                    ;;
            esac
            ;;
        $DIALOG_HELP)
            "$DIALOG" \
            --textbox "$0" 0 0
            ;;
        $DIALOG_EXTRA)
            tag=`echo "$returntext" | sed -e 's/^EDITED //' -e 's/:.*/:/'`
            item=`echo "$returntext" | sed -e 's/^[^:]*:[ ]*//' -e 's/[ ]*$//'`
            case "$tag" in
                'Firewall IP Address':)
                    fw_addr="$item"
                    ;;
                'Firewall Username':)
                    fw_user="$item"
                    ;;
                'Firewall Password':)
                    fw_pass="$item"
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
done
