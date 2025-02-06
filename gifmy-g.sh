#!/usr/bin/env bash

# auth:______max__kempter_______
# filename:______ gifmy.sh
# howto:_________ ./gifmy.sh i=705 j=839
#
# Dieses Skript erstellt eine GIF-Animation aus einer Reihe von Bildern.
# Der Benutzer gibt zwei Werte i und j an, um den Frame-Bereich zu definieren.

# Farben für die Ausgabe
export SKY="\e[38;5;26m\e[48;5;117m"
export RED="\e[38;5;203m\e[48;5;52m"
export RASPBERRY="\e[38;5;52m\e[48;5;183m"
export RESET="\e[0m"

# Sicherheitsmaßnahmen
umask 077

# Funktion zur Anzeige der Nutzung
usage() {
    echo -e "${SKY}\t Nutzung: ./gifmy.sh i=<Startwert> j=<Endwert> ${RESET}"
    exit 1
}

# Parameter-Verarbeitung
declare -A params
for arg in "$@"; do
    case $arg in
        i=*) params[i]="${arg#*=}" ;;
        j=*) params[j]="${arg#*=}" ;;
        *) usage ;;
    esac
done

# Prüfen, ob beide Parameter gesetzt sind
if [[ -z "${params[i]}" || -z "${params[j]}" ]]; then
    echo -e "${RED}\t Fehler: Beide Parameter i und j müssen gesetzt sein!${RESET}"
    usage
fi

start=${params[i]}
end=${params[j]}

# Vorhandene Bilder im Verzeichnis `out/` erfassen
mapfile -t existing_frames < <(ls out/*.webp 2>/dev/null | sed 's|out/||' | sort -n)

# Bilder basierend auf vorhandenen Dateien filtern
frames=()
for img in "${existing_frames[@]}"; do
    num=$(basename "$img" .webp)
    if [[ $num -ge $start && $num -le $end ]]; then
        frames+=("out/$img")
    fi
done

# GIF nur erstellen, wenn Bilder gefunden wurden
if [[ ${#frames[@]} -eq 0 ]]; then
    echo -e "${RED}\t Fehler: Keine gültigen Bilder im Bereich ${start}-${end} gefunden!${RESET}"
    exit 1
fi

# GIF erstellen
echo -e "${SKY}\t Erstelle GIF aus ${#frames[@]} Bildern...${RESET}"
magick "${frames[@]}" \
    -delay 1000 \
    -layers optimize-transparency \
    -coalesce \
    -morph 2 \
    -quality 1 \
    -loop 0 \
    -virtual-pixel mirror \
    out.gif

echo -e "${SKY}\t GIF erfolgreich erstellt: out.gif ${RESET}"

