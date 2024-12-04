#!/usr/bin/env bash
# auth:______max__kempter_______ 
# filename:______NIXbuild.sh 

# todo
/*
-  add function "ask_search_ext" Search for a ext
-  am Ende nach Zeile 75, frage ob suche nochmal gemacht werden soll: "
#     show_prompt "Möchtest du eine weitere Suche durchführen? (j/n)"
#    read -r answer
 #   [[ $answer != [jJ] ]] && break
#done
"
*/

# Colors are alredy defined

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
