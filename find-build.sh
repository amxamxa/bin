#!/usr/bin/env bash
# auth:______max__kempter_______
# filename: build-find.sh

# Farben für die Benutzerfreundlichkeit
LILA='\033[1;35m'  # Eingabeaufforderungen
GREEN='\033[1;32m' # Bestätigungen
RED='\033[1;31m'   # Fehler
RESET='\033[0m'    # Zurücksetzen der Farben

# Funktion zur Validierung von Eingaben
validate_input() {
  local input="$1"
  if [[ "$input" =~ [^a-zA-Z0-9._-] ]]; then
    echo -e "${RED}Ungültige Eingabe. Bitte keine Sonderzeichen verwenden.${RESET}"
    return 1
  fi
  return 0
}

# Funktion für Dateierweiterungsformatierung
format_file_extension() {
  local ext="$1"
  if [[ -z "$ext" ]]; then
    echo "*"
  elif [[ "$ext" =~ ^\.[a-zA-Z0-9]{1,3}$ ]]; then
    echo "$ext"
  elif [[ "$ext" =~ ^[a-zA-Z0-9]{1,3}$ ]]; then
    echo ".$ext"
  else
    echo -e "${RED}Ungültige Dateierweiterung. Es dürfen nur Buchstaben/Zahlen mit maximal 3 Zeichen verwendet werden.${RESET}"
    return 1
  fi
}

# Hauptfunktion
search_files() {
  while true; do
    # Suchpfad abfragen
    echo -e "${LILA}Wo möchten Sie suchen? (z. B.: \"/etc\") [Standard: /]:${RESET}"
    read -r searchPath
    searchPath="${searchPath:-/}"
    if [[ "$searchPath" =~ ^// ]]; then
      searchPath="/${searchPath#//}"
    fi
    if [[ ! "$searchPath" =~ ^/ ]]; then
      echo -e "${RED}Der Suchpfad muss mit \"/\" beginnen.${RESET}"
      continue
    fi

    # Suchbegriff abfragen
    echo -e "${LILA}Wonach möchten Sie suchen? (z. B.: \"zsh\") [Standard: *]:${RESET}"
    read -r searchTerm
    searchTerm="${searchTerm:-*}"
    validate_input "$searchTerm" || continue

    # Dateityp (Datei oder Verzeichnis) abfragen
    echo -e "${LILA}Suchen Sie nach einer Datei (f) oder einem Verzeichnis (p)? [Standard: keine]:${RESET}"
    read -r fileORpath
    if [[ "$fileORpath" != "f" && "$fileORpath" != "p" ]]; then
      echo -e "${RED}Bitte geben Sie \"f\" für Datei oder \"p\" für Verzeichnis ein.${RESET}"
      continue
    fi
    [[ "$fileORpath" == "f" ]] && typeFlag="f" || typeFlag="d"

    # Dateierweiterung abfragen, falls Dateityp Datei
    if [[ "$typeFlag" == "f" ]]; then
      echo -e "${LILA}Möchten Sie nach einer bestimmten Dateierweiterung filtern? (z. B.: .txt) [Standard: *]:${RESET}"
      read -r fileExt
      fileExt=$(format_file_extension "$fileExt") || continue
    else
      fileExt=""
    fi

    # Befehl generieren und anzeigen
    echo -e "${GREEN}Der generierte Befehl lautet:${RESET}"
    findCmd="find \"$searchPath\" -type $typeFlag -name \"$searchTerm$fileExt\""
    echo -e "${LILA}$findCmd${RESET}"

    # Bestätigung und Ausführung
    echo -e "${LILA}Soll der Befehl ausgeführt werden? (j/n):${RESET}"
    read -r confirm
    if [[ "$confirm" =~ ^[jJ]$ ]]; then
      eval "$findCmd"
    fi

    # Wiederholen?
    echo -e "${LILA}Möchten Sie eine weitere Suche durchführen? (j/n):${RESET}"
    read -r repeat
    if [[ ! "$repeat" =~ ^[jJ]$ ]]; then
      break
    fi
  done
}

# Skript starten
search_files
