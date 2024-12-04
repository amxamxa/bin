#!/usr/bin/env bash
# auth:______max__kempter_______ 
# filename:______NIXbuild.sh 


# frag nach ext
# am Ende, Frage ob cmd gemacht werden soll

    # Frage nach weiterer Suche
#add     show_prompt "Möchtest du eine weitere Suche durchführen? (j/n)"
#    read -r answer
 #   [[ $answer != [jJ] ]] && break
#done


# Define colors for UI
RESET="\e[0m"
#GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"
#RED="\033[38;2;240;138;100m\033[48;2;147;18;61m"
#LILA="\033[38;2;85;85;255m\033[48;2;21;16;46m"

# Function to ask user for search type (file or path)
ask_search_type() {
    echo -e "${LILA}Search for a file (f) or a path (p)?${RESET}"
    while true; do
        read -r file_or_path
        case $file_or_path in
            [fF] )
                echo -e "${GREEN}OK, searching for a file!${RESET}"
                return "file"
                ;;
            [pP] )
                echo -e "${GREEN}OK, searching for a path!${RESET}"
                return "path"
                ;;
            * )
                echo -e "${RED}Please enter either f or p.${RESET}"
                ;;
        esac
    done
}

# Ask user for search path
echo -e "${LILA}Where do you want to search? (e.g. /etc)${RESET}"
read -r search_path

# Ensure search path starts with "/"
if [[ $search_path != /* ]]; then
    search_path="/$search_path"
    echo -e "${GREEN}OK, searching under $search_path${RESET}"
fi

# Ask user for search term
echo -e "${LILA}What do you want to search for? (e.g. shell)${RESET}"
while true; do
    read -r search_term

    # Check if search term is at least 2 characters long
    if [[ ${#search_term} -lt 2 ]]; then
        # Add a wildcard to the search term
        search_term="${search_term}*"
    fi

    # Check if search term contains special characters (except *)
    if [[ $search_term =~ [^a-zA-Z0-9\*] ]]; then
        echo -e "${RED}Error: invalid character in search query!${RESET}"
    else
        echo -e "${GREEN}Search query is OK: $search_term${RESET}"
        break
    fi
done

# Define find command
find_command="bash -c "find $search_path -type $(ask_search_type) -name $search_term | grep --color=auto -s -I -C 1 $search_term""

# Display find command
echo -e "${GREEN}The command is: ${find_command}${RESET}"
sleep 5

# Execute find command
eval $find_command
