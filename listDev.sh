#!/usr/bin/env zsh
COMMENT=$(<< 'COMMENT'
This script lists the label, UUID, and name of block devices on the system.
It displays the device name, label, UUID, and the devices base name.
COMMENT
)
printf "${MAHOGANY}${COMMENT}\n"
# Fehlerbehandlung aktivieren
# set -euo pipefail

# Funktion, um das Label eines Blockgeräts zu erhalten
get_label() {
  local dev="$1"
  local label=$(blkid -s LABEL -o value "$dev")
  [[ -z "$label" ]] && label="${RED}<none>"
  echo "$label"
}

# Funktion, um die UUID eines Blockgeräts zu erhalten
get_uuid() {
  local dev="$1"
  local uuid=$(blkid -s UUID -o value "$dev")
  [[ -z "$uuid" ]] && uuid="<none>"
  echo "$uuid"
}

# Funktion, um den Namen eines Blockgeräts zu erhalten
get_name() {
  local dev="$1"
  echo "${dev##*/}"
}

# Funktion, um Informationen über ein Blockgerät auszugeben
print_device_info() {
  local dev="$1"
  local label=$(get_label "$dev")
  local uuid=$(get_uuid "$dev")
  local name=$(get_name "$dev")
    printf "${SKY}%-12s${RESET} 🮐 ${MINT}%-12s${RESET} 🮐 ${SKY}%-36s${RESET} 🮐 ${MINT}%-12s${RESET} 🮐\n" "$dev" "$label" "$uuid" "$name"
   #   printf "%-12s %-12s %-36s %-12s\n" "--------" "--------" "------------------------------------" "--------"
}

main() {
  # Tabellenkopf
  printf "\n${SKY}%-12s${RESET} ${MINT}%-12s${RESET} ${SKY}%-36s${RESET}  ${MINT} %-12s${RESET}\n" "  Device" "  Label" "         UUID" "Name"
  printf "%-12s %-12s %-36s %-12s\n" "------------" "------------" "------------------------------------" "------------"

  # Liste aller Blockgeräte abrufen
  devices=(/dev/sd*)

  for dev in "${devices[@]}"; do
    # Überprüfen, ob es sich um ein gültiges Blockgerät handelt
    if [[ -b "$dev" ]]; then
      print_device_info "$dev"
    else
      echo "Fehler: '$dev' ist kein gültiges Blockgerät." >&2
    fi
  done
  printf "%-12s %-12s %-36s %-12s\n" "--------" "--------" "------------------------------------" "--------"
}

# Skript ausführen
main
