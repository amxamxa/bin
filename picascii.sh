#!/usr/bin/env bash

# Farben für die Ausgabe
LILA='\033[0;35m'
RESET='\033[0m'

# Unterstützte Bildformate
formats=("*.jpg" "*.jpeg" "*.png" "*.gif" "*.JPG" "*.webp" "*.svg")

for format in "${formats[@]}"; do
    for file in $format; do
        # Überspringe, falls keine Dateien gefunden wurden
        [[ -e "$file" ]] || continue

        echo -e "\n\t${LILA}➜ $file${RESET}"
        python3 -m ascii_magic "$file" --columns 60 --width-ratio 2
        sleep 1.5
    done
done
