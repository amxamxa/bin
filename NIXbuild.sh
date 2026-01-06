#!/usr/bin/env bash
# auth:______max__kempter_______
# filename:______NIXbuilder.sh

# todo: Option Editor:     #    gnome-text-editor --ignore-session --standalone --new-window "$NixFiles" 2>/dev/null ||


# Define colors for better readability
SKY=" \033[38;2;255;0;53m\033[48;2;34;0;82m"  # pink for instructions
RED="\033[38;2;240;128;128m\033[48;2;139;0;0m"    # Red for warnings
RAS="\033[38;2;255;105;180m\033[48;2;75;0;130m" # lila for choices
GREEN="\033[38;2;252;222;90m\033[48;2;0;0;139m" # BLUE for confirmation
RESET="\033[0m"  # Reset to normal colors

# Configuration files location
EZA_COLORS="*.nix=38;5;213"; # pink
DIR="/etc/nixos"

if [ "$EUID" -ne 0 ]; then
    echo -e "\t${RAS}⚠️ This script requires administrator privileges. ⚠️ ${RESET}"
    echo -e "\t${SKY}   ...Requesting sudo permissions interactively...   ${RESET}"
    exec sudo -k "$0" "$@"
    exit 1
fi

mapfile -t NixFiles < <( find /etc/nixos -name "*.nix"  -not -name "hardware-configuration.nix" -not -path "*/bkp/*"  -not -path "*/out-of-use/*"  -not -path "*/read-only/*" )

echo -e "\t${RAS}This Script found nix-files: \t ${#NixFiles[@]}${RESET}"
echo -e "\t\t${SKY}their names are:${RESET}\n"


if command -v eza &>/dev/null; then
	  eza --grid --long --no-permissions --no-user --time-style=relative "${NixFiles[@]}"
  else
       ls -Flrh "${NixFiles[@]}"
fi

# Countdown function with cancellation option
 countdown() {
    secs=10
    while [ $secs -gt 0 ]; do
        echo -ne "\t⏳ Press Enter to confirm or Ctrl+C to cancel... ($secs)\r"
        # Sicherer Read mit Timeout und Unterdrückung von Backslashes
        if IFS= read -r -t 1 -n 1; then 
            break
        fi
        secs=$((secs-1))
    done
    echo -ne "\n"
}

# 1. EDITOR SELECTION
echo -e "\n\t${RAS}📝 STEP 1: Edit Configuration Files (Optional)${RESET}"
# Robuste Validierung für Ja/Nein
while true; do
    read -r -p "$(echo -e "\t${SKY}Open editor? ${RAS}(Enter for Yes, n/N for No): ${RESET}")" editor_choice
    case "$editor_choice" in
        [nN]*) 
            echo -e "\t\t${GREEN}Skipping file editing...${RESET}"
            DO_EDIT="no"
            break ;;
        ""|[yY]*) 
            echo -e "\t\t${GREEN}Opening configuration files in editor...${RESET}"
            DO_EDIT="yes"
            break ;;
        *) echo -e "\t${RED}Invalid input. Please use Enter/y or n.${RESET}" ;;
    esac
done

if [[ "$DO_EDIT" == "yes" ]]; then
 	"$EDITOR" "${NixFiles[@]}" || nano "${NixFiles[@]}"
fi
echo

# 2. BUILD METHOD SELECTION
echo -e "\n\t${RAS}⚙️ STEP 2: Choose Build Method${RESET}"
echo -e "\t${RAS}How do you want to apply your new configuration?"
echo -e "\t${SKY}  [s] switch  ${RESET}- Apply immediately (default, safest)"
echo -e "\t${SKY}  [b] boot    ${RESET}- Apply at next reboot (good for major changes)"
echo -e "\t${SKY}  [v] vm      ${RESET}- Build in virtual machine (test without changing real system)${RESET}"

while true; do
    read -r -p "$(echo -e "\n\t${RAS}Your choice? ${SKY}(s/b/v) [Default: s]: ${RESET}")" build_choice
    case "${build_choice,,}" in # ,, wandelt in Kleinbuchstaben um für robustere Prüfung
        b) BUILD="boot"; METHOD="Boot at next restart"; break ;;
        s|"") BUILD="switch"; METHOD="Apply immediately"; break ;;
        v) BUILD="build-vm"; METHOD="Test in Virtual Machine"; break ;;
        *) echo -e "\t${RED}❌ Invalid choice. Please select s, b, or v.${RESET}" ;;
    esac
done
echo -e "\t\t${GREEN}Selected: ${SKY}$METHOD${RESET}"
echo

# 3. PACKAGE UPDATE OPTION
echo -e "\n\t${RAS}🔄 STEP 3: Package Updates${RESET}"
echo -e "\t${RAS}Do you want to update your packages before building?"
echo -e "\tThis fetches the latest software versions from NixOS channels${RESET}"

while true; do
    read -r -p "$(echo -e "\n\t${SKY}Update packages? ${RAS}(Enter for Yes, n for No): ${RESET}")" upgrade_choice
    case "$upgrade_choice" in
        [nN]*) 
            UPGRADE=""
            echo -e "\t${GREEN}Keeping current package versions...${RESET}"
            break ;;
        ""|[yY]*) 
            UPGRADE="--upgrade"
            echo -e "\t${GREEN}Updating to latest packages...${RESET}"
            break ;;
        *) echo -e "\t${RED}Invalid input. Please use Enter/y or n.${RESET}" ;;
    esac
done
echo

# 4. SYSTEM VERSION NAMING
echo -e "\n\t${RAS}🏷️ STEP 4: Name Your System Version${RESET}"
default_name=$(date +"%Y-%B")
echo -e "\t${RAS}... this system version a name for identification"
echo -e "\t${SKY}Default name: ${GREEN}$default_name${RESET} (based on current date)"
# IFS= leer lassen, um Leerzeichen im Namen zu erlauben, falls gewünscht
IFS= read -r -p "$(echo -e "\n\t${GREEN} Your custom name or press Enter for default: ${RESET}")" profile_name

NAME="${profile_name:-$default_name}"
echo -e "\t${GREEN}System version name: ${RAS}$NAME${RESET}"
echo

# 5. CONFIRMATION BEFORE BUILDING
echo -e "\n\t${RAS}✅ STEP 5: Confirm Settings${RESET}"
echo -e "\t${GREEN}Review your choices before building:"
echo -e "\t${SKY}● Build Method: \t${GREEN}$METHOD${RESET}"
echo -e "\t${SKY}● Package Update:\t${GREEN}$([ -n "$UPGRADE" ] && echo "Yes" || echo "No")${RESET}"
echo -e "\t${SKY}● Version Name: \t${GREEN}$NAME${RESET}"
echo -e "\n\t${RAS}The following command will be executed:"
echo -e "\t${SKY}sudo nixos-rebuild $BUILD $UPGRADE --show-trace --profile-name \"$NAME\"${RESET}"

countdown

# 6. EXECUTE THE BUILD
echo -e "\n\t${GREEN}🚀 Building your NixOS system...${RESET}"
echo -e "\t${SKY} please be patient and don't interrupt the process${RESET}\n"

sudo nixos-rebuild "$BUILD" --show-trace $UPGRADE --profile-name "$NAME" -I nixos-config=/etc/nixos/configuration.nix

# 7. FINAL FEEDBACK
if [ $? -eq 0 ]; then
    echo -e "\n\t${GREEN}✅ Build successful! Your system is ready${RESET}"
    case $BUILD in
        switch) echo -e "\t${GREEN}Your new configuration is now active${RESET}" ;;
        boot) echo -e "\t${GREEN}Choose ${NAME} in boot menu at next restart${RESET}" ;;
        build-vm) echo -e "\t${GREEN}Virtual machine built. Test with ./result/bin/run-*-vm ${RESET}" ;;
    esac
else
    echo -e "\n\t${RED}❌ Build encountered errors. Check output above${RESET}"
    echo -e "\tCommon fixes:"
    echo -e "\t - Check configuration for syntax errors"
    echo -e "\t - Ensure internet connection is working"
    echo -e "\t - Try running with --upgrade if packages are missing${RESET}"
fi

