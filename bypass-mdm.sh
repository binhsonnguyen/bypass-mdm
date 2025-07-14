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

# --- Functions ---

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
    # Get the system volume name dynamically
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
    realName="${realName:-Apple}"
    read -p "Enter Temporary Username (Default is 'Apple'): " username
    username="${username:-Apple}"
    read -p "Enter Temporary Password (Default is '1234'): " passw
    passw="${passw:-1234}"

    # Create User
    local dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
    local user_home_dir="/Volumes/Data/Users/${username}"
    echo -e "${GRN}Creating Temporary User '$username'..."
    mkdir -p "$user_home_dir"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/${username}"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/${username}" UserShell "/bin/zsh"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/${username}" RealName "$realName"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/${username}" UniqueID "501"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/${username}" PrimaryGroupID "20"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/${username}" NFSHomeDirectory "/Users/${username}"
    dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/${username}" "$passw"
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

    # Block MDM domains
    echo -e "${YEL}Blocking MDM domains...${NC}"
    cat << EOF >> "${system_volume_path}/etc/hosts"
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 iprofiles.apple.com
EOF
    echo -e "${GRN}Successfully blocked MDM & Profile Domains"

    # Remove configuration profiles
    local config_profile_dir="${system_volume_path}/var/db/ConfigurationProfiles/Settings"
    touch /Volumes/Data/private/var/db/.AppleSetupDone
    rm -f "${config_profile_dir}/.cloudConfigHasActivationRecord"
    rm -f "${config_profile_dir}/.cloudConfigRecordFound"
    touch "${config_profile_dir}/.cloudConfigProfileInstalled"
    touch "${config_profile_dir}/.cloudConfigRecordNotFound"

    echo -e "${GRN}MDM enrollment has been bypassed!${NC}"
    echo -e "${NC}Exit terminal and reboot your Mac.${NC}"
}

disable_notification_sip() {
    # Disable Notification (SIP) - This runs on a booted OS
    echo -e "${RED}Please Insert Your Password To Proceed${NC}"
    sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
    sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
    sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
    sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
    echo -e "${GRN}Disabled MDM notifications.${NC}"
}

disable_notification_recovery() {
    # Disable Notification (Recovery)
    local system_volume
    system_volume=$(get_system_volume)
    local config_profile_dir="/Volumes/${system_volume}/var/db/ConfigurationProfiles/Settings"

    echo -e "${YEL}Disabling MDM notifications on volume ${system_volume}...${NC}"
    rm -f "${config_profile_dir}/.cloudConfigHasActivationRecord"
    rm -f "${config_profile_dir}/.cloudConfigRecordFound"
    touch "${config_profile_dir}/.cloudConfigProfileInstalled"
    touch "${config_profile_dir}/.cloudConfigRecordNotFound"
    echo -e "${GRN}Disabled MDM notifications.${NC}"
}

check_mdm_enrollment() {
    # Check MDM Enrollment - This runs on a booted OS
    echo ""
    echo -e "${YEL}Attempting to check MDM enrollment status...${NC}"
    echo "If the command below fails or shows an error, it's a good sign that the bypass was successful."
    echo ""
    echo -e "${RED}Please Insert Your Password To Proceed${NC}"
    echo ""
    sudo profiles show -type enrollment || true
}

reboot_system() {
    # Reboot & Exit
    echo "Rebooting..."
    reboot
}


# --- Main Script ---

# Display header
echo -e "${CYAN}Bypass MDM Utility${NC}"
echo ""

# Prompt user for choice
PS3='Please enter your choice: '
options=(
    "Bypass MDM (Run from Recovery)"
    "Disable Notifications (Run from Recovery)"
    "Check MDM Enrollment (Run on Booted OS)"
    "Disable Notifications (Run on Booted OS with SIP off)"
    "Reboot Mac"
    "Quit"
)
select opt in "${options[@]}"; do
    case $opt in
        "Bypass MDM (Run from Recovery)")
            perform_mdm_bypass_recovery
            break
            ;;
        "Disable Notifications (Run from Recovery)")
            disable_notification_recovery
            ;;
        "Check MDM Enrollment (Run on Booted OS)")
            check_mdm_enrollment
            ;;
        "Disable Notifications (Run on Booted OS with SIP off)")
            disable_notification_sip
            ;;
        "Reboot Mac")
            reboot_system
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "Invalid option $REPLY" ;;
    esac
done