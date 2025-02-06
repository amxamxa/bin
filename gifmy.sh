#!/usr/bin/env bash
# mit DEEPSEEK

# auth: max kempter
# filename: gifmy.sh
# howto: ./gifmy.sh i=705 j=839
# Erklärung: Erstellt ein animiertes GIF aus WebP-Bildern im Bereich i-j mit Hin- und Rücklauf.
# Nutzung: Parameter i und j als Start/Ende der Bildsequenz angeben.

# Farbdefinitionen
SKY="\033[38;2;62;36;129m\033[48;2;135;206;235m"
RED="\033[38;2;240;128;128m\033[48;2;139;0;0m"
RASPBERRY="\033[38;2;32;0;21m\033[48;2;221;160;221m"
NC="\033[0m"

print_help() {
  echo -e "${SKY}Verwendung:${NC}"
  echo -e "${SKY}\t$0 i=<START> j=<ENDE>"
  echo -e "${SKY}Beispiel: ./gifmy.sh i=705 j=839"
  echo -e "${SKY}Beschreibung: Erstellt GIF aus WebPs in 'out/' zwischen i-j mit Morph-Effekt.${NC}"
  exit 0
}

umask 0022

# Hilfebefehl prüfen
if [[ $# -eq 0 || "$1" =~ ^(-h|--help)$ ]]; then
  print_help
fi

# Parameter extrahieren
i=""; j=""
for arg in "$@"; do
  if [[ "$arg" == i=* ]]; then
    i="${arg#i=}"
  elif [[ "$arg" == j=* ]]; then
    j="${arg#j=}"
  else
    echo -e "${RED}\tUngültiger Parameter: '$arg'${NC}" >&2
    exit 1
  fi
done

# Validierung
[[ -z "$i" || -z "$j" ]] && { echo -e "${RED}\tBeide Parameter benötigt!${NC}" >&2; exit 1; }
[[ ! "$i$j" =~ ^[0-9]+$ ]] && { echo -e "${RED}\tNur numerische Werte erlaubt!${NC}" >&2; exit 1; }
(( 10#$i > 10#$j )) && { echo -e "${RED}\ti muss ≤ j sein!${NC}" >&2; exit 1; }

# Dateiliste generieren
declare -a valid_files
shopt -s nullglob
for f in out/*.webp; do
  num=$(basename "${f%.webp}")
  [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 10#$i && num <= 10#$j )) && valid_files+=("$f")
done
shopt -u nullglob

[[ ${#valid_files[@]} -eq 0 ]] && { echo -e "${RED}\tKeine passenden Dateien gefunden!${NC}" >&2; exit 1; }

# Sortieren und Listen kombinieren
IFS=$'\n' sorted=($(sort -V <<< "${valid_files[*]}"))
unset IFS

descending=()
for ((idx=${#sorted[@]}-2; idx>=0; idx--)); do
  descending+=("${sorted[idx]}")
done

combined=("${sorted[@]}" "${descending[@]}")

# Magick-Befehl
command -v magick >/dev/null || { echo -e "${RED}\tImageMagick nicht installiert!${NC}" >&2; exit 1; }

echo -e "${SKY}\tStarte GIF-Erstellung mit ${#combined[@]} Bildern...${NC}"
magick "${combined[@]}" -delay 1000 -layers optimize-transparency -coalesce -morph 2 -quality 1 -loop 0 -virtual-pixel mirror out.gif

[[ $? -eq 0 ]] && echo -e "${SKY}\tGIF erfolgreich als out.gif gespeichert!${NC}" || echo -e "${RED}\tFehler bei der GIF-Erstellung!${NC}" >&2

