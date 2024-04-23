#!/bin/sh

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
kit_num=""          #             ||
int_num=""          #             ||
wan_addr=""         #             ||
peer_addr=""        #             ||
psk_key=""          #             \/
pass_cover="" # - Veil the sensitive values -
psk_cover="" # --------------------------------
returncode=0        # - Initialize
defaultitem="FW IP Address:"    # - Set default input field
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
            --inputmenu "$DIALOG_TITLE" \
30 80 10 \
        "FW IP Address:"        "$fw_addr"      "The IP address of your kit's Palo Alto FW" \
        "FW Username:"          "$fw_user"      "The username of your kit's Palo Alto FW account that can create and apply configuration" \
        "FW Password:"          "$pass_cover"      "The password of your kit's Palo Alto FW account" \
        "Team Number:"          "$team_num"     "Your CPT number; ie 401, 154, 03, 600" \
        "Kit Number:"           "$kit_num"      "Your kit number; ie 102, 14, 43, 69" \
        "WAN Interface:"        "$int_num"      "The WAN interface you want to apply this tunnel to; should really only be Untrust (1/'X')" \
        "WAN IP Address:"       "$wan_addr"     "The IP address you want to give to the WAN interface for this tunnel" \
        "Peer IP Address:"      "$peer_addr"    "The IP address of the Juniper you are creating a tunnel to" \
        "Pre-Shared Key:"       "$psk_cover"      "The shared key that is decided when discussing the need for this tunnel to be created; must be the same on both sides" \
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
                    "$DIALOG" \
                    --clear \
                    --backtitle "$backtitle" \
                    --msgbox "A progress bar will go here and things will be done..." 10 40
##########          --progressbox           ##############################
                    ;;
            esac
            DIALOG_TITLE="\t- \Z1Welcome to AutoVPN.\Zn"
            ;;
        $DIALOG_ESTABLISH)
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
##########          --progressbox           ##############################
                    ;;
            esac
            DIALOG_TITLE="\t- \Z2Welcome to AutoVPN.\Zn"
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
                    pass_cover="******"
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
                    psk_cover="******"
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