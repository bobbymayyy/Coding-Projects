#!/bin/sh

#This is a dialog "gui" for creating tunnels through Palo Alto CLI configuration changes...

. ./setup-vars
backtitle="AutoVPN - A utility for easily creating IPSEC tunnels in Palo Alto"

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
        "WAN Interface:"        "$int_num"      "The WAN interface you want to apply this tunnel to; should really only be Untrust (1/'X') \
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
                --yesno "Are you sure you want to quit?" 10 30
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
###########             --progressbox           ##############################
                        ;;
                esac
                ;;
        $DIALOG_HELP)
                "$DIALOG" \
                --textbox "$0" 0 0
                ;;
        esac
done
