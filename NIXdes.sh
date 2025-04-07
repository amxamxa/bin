 #!/usr/bin/env bash
 #  Skript zur Anzeige aller per nix-env installierten Nix-Pakete samt Beschreibung – optisch strukturiert, technisch robust und direkt nutzbar.
 # Pakete ohne Beschreibung oder solche, bei denen nix-instantiate fehlschlägt (z. B. bei fehlender Referenz in <nixpkgs>), werden abgefangen und farblich markiert.
  # Mit nix-instantiate wird pro Paket der Ausdruck $packageName.meta.description evaluiert. Durch Verwendung von --eval und --json kann das Ergebnis sauber per jq verarbeitet werden. Falls eine Beschreibung existiert, wird sie angezeigt – andernfalls erscheint ein Fehlerhinweis.
 # ROADMAP: - Variante zeigen, die systemweite Pakete berücksichtigt (nicht nur nix-env) – oder eine Version mit Markdown-Export für Doku-Zwecke.

 # Define ANSI color codes for UI styling
 VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"         # Prompt color
 RESET="\e[0m"                                             # Reset color
 GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"              # Success color
 RED="\033[38;2;240;138;100m\033[48;2;147;18;61m"         # Error color
 PINK="\033[38;2;85;85;255m\033[48;2;21;16;46m"           # Interaction prompt
 
 # Function: list_nix_packages_with_description
 # Purpose: 
 #   1. Lists all installed packages via nix-env, stripping their version numbers.
 #   2. Fetches and displays the package descriptions using nix-instantiate and jq.
 list_nix_packages_with_description() {
   # Define a temporary file to store package names (without versions)
   local packageListFile="/tmp/nix_installed_packages.txt"
 
   # Print a colored header indicating what this script does
   echo -e "\n${PINK}Command:${RESET} nix-env --query --installed"
   echo -e "${VIOLET}→ Showing installed Nix packages (no version), including descriptions:${RESET}\n"
 
   # Step 1: Get installed packages
   # nix-env --query --installed outputs packages like "htop-3.2.2"
   # We strip version suffixes with sed and write the clean names to a file
   nix-env --query --installed \
     | sed -E 's/-[0-9.]+$//' \
     | sort -u \
     > "$packageListFile"
 
   # Feedback: Show where the list was saved
   echo -e "${GREEN}✔ Package list saved to: $packageListFile${RESET}\n"
 
   # Step 2: Iterate through each package name and fetch description
   while IFS= read -r packageName; do
     # Attempt to extract the package's meta.description
     description=$(nix-instantiate \
       --eval -E "with import <nixpkgs> {}; $packageName.meta.description" \
       --json 2>/dev/null | jq -r)
 
     # Output the result, handle missing or null descriptions
     if [[ -n "$description" && "$description" != "null" ]]; then
       echo -e "${GREEN}$packageName:${RESET} $description"
     else
       echo -e "${RED}$packageName:${RESET} No description found or invalid package"
     fi
   done < "$packageListFile"
 }
 
 # Run the function if this script is executed directly
 # Useful when calling the script as ./NIXdes.sh
 if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
   list_nix_packages_with_description
 fi
 
 
 
