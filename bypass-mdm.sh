#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

get_system_volume() {
    local volume_name
    volume_name=$(diskutil info / | grep "Volume Name:" | awk -F': ' '{print $2}')

    if [[ -z "$volume_name" ]]; then
        echo -e "${RED}Error: Could not determine the system volume name. Exiting.${NC}" >&2
        exit 1
    fi
    echo "$volume_name" | xargs
}

perform_mdm_bypass_recovery() {
    local system_volume
    system_volume=$(get_system_volume)
    local system_volume_path="/Volumes/${system_volume}"
    local data_volume_path="/Volumes/${system_volume} - Data"

    echo -e "${YEL}Bypass MDM from Recovery on volume: ${system_volume}${NC}"

    if [ -d "$data_volume_path" ]; then
        echo "Renaming '$data_volume_path' to '/Volumes/Data'..."
        diskutil rename "$data_volume_path" "Data"
    fi

    # Create Temporary User
    echo -e "${NC}Create a Temporary User"
    read -p "Enter Temporary Fullname (Default is 'Apple'): " realName
    realName="${realName:=Apple}"
    read -p "Enter Temporary Username (Default is 'Apple'): " username
    username="${username:=Apple}"
    read -p "Enter Temporary Password (Default is '1234'): " passw
    passw="${passw:=1234}"

    # Create User
    dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
    echo -e "${GREEN}Creating Temporary User"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
    mkdir "/Volumes/Data/Users/$username"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
    dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership $username

    # Block MDM domains
    echo "0.0.0.0 deviceenrollment.apple.com" >>/Volumes/Macintosh\ HD/etc/hosts
    echo "0.0.0.0 mdmenrollment.apple.com" >>/Volumes/Macintosh\ HD/etc/hosts
    echo "0.0.0.0 iprofiles.apple.com" >>/Volumes/Macintosh\ HD/etc/hosts
    echo -e "${GRN}Successfully blocked MDM & Profile Domains"

    # Remove configuration profiles
    touch /Volumes/Data/private/var/db/.AppleSetupDone
    rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
    rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
    touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
    touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound

    echo -e "${GRN}MDM enrollment has been bypassed!${NC}"
    echo -e "${NC}Exit terminal and reboot your Mac.${NC}"
}

disable_notification_sip() {
    # Disable Notification (SIP)
    echo -e "${RED}Please Insert Your Password To Proceed${NC}"
    sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
    sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
    sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
    sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
}

disable_notification_recovery() {
    # Disable Notification (Recovery)
    rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
    rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
    touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
    touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
}

check_mdm_enrollment() {
    # Check MDM Enrollment
    echo ""
    echo -e "${GRN}Check MDM Enrollment. Error is success${NC}"
    echo ""
    echo -e "${RED}Please Insert Your Password To Proceed${NC}"
    echo ""
    sudo profiles show -type enrollment
}

reboot_system() {
    # Reboot & Exit
    echo "Rebooting..."
    reboot
}

# Display header
echo -e "${CYAN}Bypass MDM${NC}"
echo ""

# Prompt user for choice
PS3='Please enter your choice: '
options=(
    "Bypass MDM from Recovery"
    "Disable Notification (SIP)"
    "Disable Notification (Recovery)"
    "Check MDM Enrollment"
    "Exit & Reboot"
)
select opt in "${options[@]}"; do
    case $opt in
        "Bypass MDM from Recovery")
            perform_mdm_bypass_recovery
            break
            ;;
        "Disable Notification (SIP)")
            disable_notification_sip
            break
            ;;
        "Disable Notification (Recovery)")
            disable_notification_recovery
            break
            ;;
        "Check MDM Enrollment")
            check_mdm_enrollment
            break
            ;;
        "Reboot & Exit")
            reboot_system
            break
            ;;
        *) echo "Invalid option $REPLY" ;;
    esac
done
