#!/usr/bin/env zsh
COMMENT=$(<< 'COMMENT'
This script lists the label, UUID, and name of block devices on the system.
It displays the device name, label, UUID, and the devices base name.

COMMENT
)
echo -e "${MAHOGANY}${COMMENT}${RESET}"
# Fehlerbehandlung aktivieren
# set -euo pipefail

# Funktion, um sudo-Rechte zu prüfen
check_sudo() {
  if [[ $EUID -ne 0 ]]; then
    echo "Dieses Skript erfordert sudo-Rechte. Bitte Passwort eingeben:"
    sudo -v || exit 1
  fi
}

# Funktion, um das Partitionsschema (PTTYPE) und UUID (PTUUID) eines Blockgeräts zu erhalten
get_partition_info() {
  local dev="$1"
  local pttype=$(blkid -s PTTYPE -o value "$dev")
  local ptuuid=$(blkid -s PTUUID -o value "$dev")

  # Setze Standardwerte, falls keine Infos vorhanden
  [[ -z "$pttype" ]] && pttype="<none>"
  [[ -z "$ptuuid" ]] && ptuuid="<none>"
  
  echo "$pttype" "$ptuuid"
}

# Funktion, um das Label eines Blockgeräts zu erhalten
get_label() {
  local dev="$1"
  local label=$(blkid -s LABEL -o value "$dev")
  [[ -z "$label" ]] && label="<none>"
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
  local pttype=""
  local ptuuid=""

  # Wenn PTTYPE "gpt" ist, PTTYPE und PTUUID anzeigen
  read pttype ptuuid <<< $(get_partition_info "$dev")
  [[ "$pttype" == "gpt" ]] && label="$pttype" && uuid="$ptuuid"

  # Ausgabe formatieren
  printf "${SKY}%-12s${RESET} 🮐 ${MINT}%-12s${RESET} 🮐 ${SKY}%-36s${RESET} 🮐 ${MINT}%-12s${RESET} 🮐\n" "$dev" "$label" "$uuid" "$name"
}

main() {
  # Prüfen, ob User sudo-Rechte hat
  check_sudo

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
