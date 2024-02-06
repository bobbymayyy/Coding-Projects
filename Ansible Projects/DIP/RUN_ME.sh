#!/bin/bash
#THIS IS THE DIP (DEPLOYABLE INFRASTRUCTURE PLATFORM); IF YOU HAVE ANY QUESTIONS DEFER TO SPC MAY WITH THE CPB NERD.

#Puts a wait in the script
debugger() {
    echo "--------------------"
    echo "Press any key to continue..."
    read -rsn1
}

#Checks some things as prerequisites for deploying DIP
status_check() {
  internet=$(ping 8.8.8.8 | grep "bytes from") & #Tests connection to 8.8.8.8
  dns=$(ping google.com | grep "bytes from") & #Tests connection to google.com
  nic=$(ip a | grep "master vmbr0") #Grabs NIC of script host
  ipaddr=$(ip a | grep "global vmbr0" | awk '{print $2}') #Grabs IP of script host
  pvedaemon=$(ps -x | awk '{print $5}' | egrep ^pvedaemon) #Determines if script host is Proxmox
}

#Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

#Create some temporary files and make sure they go away when we are done
tmp_file=$(tempfile 2>/dev/null) || tmp_file=/tmp/test$$
trap "rm -f $tmp_file" 0 1 2 5 15

#Test to see that it is the correct password and push back to unseal function if not
validate_vault() {
  echo "${VAULT_PASS}" | ansible-vault view ./docs/passwords.yml --vault-pass-file=/bin/cat 2>&1 > /dev/null
  if [ $? -eq 1 ]; then
    VAULT_SUCCESS=FALSE
    echo "PASSWORD INVALID! Press enter to continue..."
    unset $VAULT_PASS
    read
  else
    VAULT_SUCCESS=TRUE
  fi
}

#Have user input a password to un-encrypt the vault; Password will be agreed upon beforehand
unseal_vault() {
  VAULT_PASS=`dialog --backtitle "DIP (Deployable Infrastructure Platform)" \
          --title "Unseal Vault" \
          --insecure  "$@" \
          --passwordbox "Please enter the password to the Ansible Vault:" 9 62 2>&1 > /dev/tty`
  validate_vault
}

#Infrastructure menu for DIP
infra_menu() {
  #See status check function
  status_check

  dialog --colors \
          --backtitle "DIP (Deployable Infrastructure Platform)" \
          --title "Infrastructure Menu" "$@" \
          --checklist "Deploy some Infrastructure! \n\
  Select the infrastructure you would like to deploy. \n\n\
  PVE$(if [ -n "$pvedaemon" ]; then echo -e "\t- \Z2YES\Zn"; else echo -e "\t- \Z1NO\Zn"; fi) \n\
  INTERNET$(if [ -n $internet ]; then echo -e "\t- \Z2SUCCESS\Zn"; else echo -e "\t- \Z1FAILURE\Zn"; fi) \n\
  DNS$(if [ -n $dns ]; then echo -e "\t- \Z2SUCCESS\Zn"; else echo -e "\t- \Z1FAILURE\Zn"; fi) \n\
  $(echo $ipaddr) \n\n\
  Which of the following would you like to setup?" 21 62 5 \
          "Networking" "Router and vSwitches." on \
          "Nextcloud" "C2 - Local SAAS Storage." off \
          "Mattermost" "C2 - Team Communication." off \
          "Redmine" "C2 - Management/Issue Tracking." off \
          "Security Onion" "Distributed Deployment." off 2> $tmp_file

  #Set return_value variable to previous commands return code
  return_value=$?

  clear
  #Handle menu progression
  case $return_value in
    $DIALOG_OK)
      PROX_SUCCESS=FALSE
      while [ $PROX_SUCCESS == FALSE ]; do
        PROX_PASS1=`dialog --backtitle "DIP (Deployable Infrastructure Platform)" \
            --title "Proxmox Password" \
            --insecure  "$@" \
            --passwordbox "Please enter the password you gave root on Proxmox:" 9 62 2>&1 > /dev/tty`
        PROX_PASS2=`dialog --backtitle "DIP (Deployable Infrastructure Platform)" \
            --title "Proxmox Password" \
            --insecure  "$@" \
            --passwordbox "Please confirm the password:" 9 62 2>&1 > /dev/tty`
        if [ $PROX_PASS1 == $PROX_PASS2 ]; then
          PROX_SUCCESS=TRUE
          debugger
          #...
        else
          PROX_SUCCESS=FALSE
          echo "PASSWORD DOES NOT MATCH! Press enter to continue..."
          unset $PROX_PASS1
          unset $PROX_PASS2
          read
        fi
      done
      ;;
    $DIALOG_CANCEL)
      echo "Cancel pressed.";;
    $DIALOG_HELP)
      echo "Help pressed.";;
    $DIALOG_EXTRA)
      echo "Extra button pressed.";;
    $DIALOG_ITEM_HELP)
      echo "Item-help button pressed.";;
    $DIALOG_ESC)
      if test -s $tmp_file ; then
        cat $tmp_file
      else
        echo "ESC pressed."
      fi
      ;;
  esac
}



#===========================================================================================================================================================
#======================================================================================================================================



#Set vault success for default; loop vault is unsealed with correct password
VAULT_SUCCESS=FALSE
while [ $VAULT_SUCCESS == FALSE ]; do
unseal_vault
done

#Main menu for DIP
MAIN_MENU=TRUE
while [ $MAIN_MENU == TRUE ]; do
  dialog --colors \
          --backtitle "DIP (Deployable Infrastructure Platform)" \
          --title "Main Menu" "$@" \
          --menu "Welcome to the DIP! \n\
  This is a process made to ease setup of Infrastructure. \n\n\
  What would you like to do?" 14 62 5 \
          "Infrastructure" "Select deployment or teardown." \
          "View Vault" "See all your passwords." \
          "Error Correction" "Attempt error correction to deploy." \
          "Teardown" "Teardown and start over." 2> $tmp_file

  #Set return_value variable to previous commands return code
  return_value=$?

  clear
  #Handle menu progression  
  case $return_value in
    $DIALOG_OK)
      if [[ "$(cat $tmp_file)" =~ "Infrastructure" ]]; then
        infra_menu
      elif [[ "$(cat $tmp_file)" =~ "View Vault" ]]; then
        echo "${VAULT_PASS}" | ansible-vault view ./docs/passwords.yml --vault-pass-file=/bin/cat
        debugger
      elif [[ "$(cat $tmp_file)" =~ "Error Correction" ]]; then
        echo "Performing error correction..."
        debugger
      elif [[ "$(cat $tmp_file)" =~ "Teardown" ]]; then
        echo "Tearing everything down..."
        debugger
      fi;;
    $DIALOG_CANCEL)
      echo "Cancel pressed."
      MAIN_MENU=FALSE;;
    $DIALOG_HELP)
      echo "Help pressed.";;
    $DIALOG_EXTRA)
      echo "Extra button pressed.";;
    $DIALOG_ITEM_HELP)
      echo "Item-help button pressed.";;
    $DIALOG_ESC)
      if test -s $tmp_file ; then
        cat $tmp_file
      else
        echo "ESC pressed."
        MAIN_MENU=FALSE
      fi
      ;;
  esac
done








unset $VAULT_PASS
unset $PROX_PASS1
unset $PROX_PASS2
echo "Goodbye :)"