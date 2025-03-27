#!/usr/bin/env bash

# Farbdefinitionen (ANSI Escape Codes)
LILA='\033[0;35m'
RESET='\033[0m'

# Unterstützte Bildformate
formats=("*.jpg" "*.jpeg" "*.png" "*.gif" "*.JPG" "*.webp" "*.svg")

# Prüfe, ob `artem` installiert ist
if ! command -v artem &> /dev/null; then
    echo -e "${LILA}Fehler:${RESET} 'artem' ist nicht installiert. Installiere es mit:"
    echo "cargo install artem"
    exit 1
fi

# Zeige jedes Bild mit artem an
for format in "${formats[@]}"; do
    for file in $format; do
        # Überspringe, falls keine Dateien gefunden wurden
        [[ -e "$file" ]] || continue

        echo -e "\n\t${LILA}➜ $file${RESET}"
        artem "$file"
        sleep 1.5
    done
done

echo -e "\n${LILA}✓ Alle Bilder angezeigt.${RESET}"
