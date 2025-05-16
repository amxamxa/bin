#!/usr/bin/env bash
################################################################################
#   ________author:______amxamxa___________________
#    _ _ _filename:______emptines-killer.sh_______________________
#
#            Space to Dash Filename Converter
#           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# This script recursively processes directories and files, replacing spaces
# in names with dashes (default) or removing spaces entirely (with -s option).
#
# emptiness-killer.sh - Ein Skript zum Entfernen/Ersetzen von Leerzeichen in Datei- und Verzeichnisnamen

# Sicherheitshinweise:
# - Das Skript schützt Systemverzeichnisse standardmäßig vor Änderungen
# - Benutzer wird vor jeder Änderung gefragt (außer bei -a Bestätigung)
# - Trockenlauf-Modus (-n) ermöglicht sichere Tests
# - Behandelt Sonderzeichen in Dateinamen korrekt
# - Erstellt Backup nicht automatisch - Benutzer sollte wichtige Daten sichern
#!/usr/bin/env bash

# ============================================================================
# Skript zum rekursiven Umbenennen von Dateien/Verzeichnissen durch Ersetzen
# oder Entfernen von Leerzeichen. Unterstützt interaktive Vorschau, dry-run,
# Farbausgaben, Systemverzeichnis-Schutz, max. Tiefe, und mehr.
# ----------------------------------------------------------------------------
============= Farben definieren ===============================
COL_USER="\033[38;2;0;17;204m\033[48;2;147;112;219m"
COL_ACCENT="\033[38;2;32;0;21m\033[48;2;163;64;217m"
COL_RES="\033[38;2;252;222;90m\033[48;2;0;0;139m"
COL_SUCCESS="\033[38;2;0;255;0m\033[48;2;0;100;0m"
COL_ERROR="\033[38;2;240;128;128m\033[48;2;139;0;0m"
COL_RESET="\033[0m"

# =============================== Default-Werte ====================================
REMOVE_SPACES=false
DRY_RUN=false
FORCE=false
DEPTH=2
CONFIRM_ALL=false

# =============================== Hilfsfunktionen ================================

# Funktion zur farbigen Ausgabe
print_msg() {
  local type="$1"
  local msg="$2"
  case $type in
    "info")    echo -e "\t${COL_ACCENT}${msg}${COL_RESET}" ;;
    "success") echo -e "\t${COL_SUCCESS}${msg}${COL_RESET}" ;;
    "error")   echo -e "\t${COL_ERROR}${msg}${COL_RESET}" >&2 ;;
    "prompt")  echo -e "\t${COL_USER}${msg}${COL_RESET}" ;;
  esac
}

# Funktion zur Anzeige von Hilfe
show_help() {
  cat << EOF
Verwendung: $0 [Optionen] [Verzeichnis]

Optionen:
  -s, --no-space      Leerzeichen komplett entfernen statt durch Bindestriche zu ersetzen
  -d N, --depth N     Tiefe der Verzeichnissuche (Standard: 2)
  -n, --dry-run       Nur anzeigen, nicht wirklich umbenennen
  -f, --force         Systemverzeichnisse nicht schützen
  -h, --help          Diese Hilfe anzeigen
EOF
  exit 0
}

# Systemverzeichnisse schützen
is_protected_dir() {
  local path="$1"
  [[ "$path" == "/" || "$path" == "/bin" || "$path" == "/boot" || \
     "$path" == "/dev" || "$path" == "/etc" || "$path" == "/lib" || \
     "$path" == "/proc" || "$path" == "/root" || "$path" == "/sbin" || \
     "$path" == "/sys" || "$path" == "/usr" || "$path" == "/var" ]]
}

# ============================== Argumentverarbeitung ============================
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--no-space)
      REMOVE_SPACES=true
      shift ;;
    -d|--depth)
      DEPTH="$2"
      shift 2 ;;
    -n|--dry-run)
      DRY_RUN=true
      shift ;;
    -f|--force)
      FORCE=true
      shift ;;
    -h|--help)
      show_help ;;
    *)
      POSITIONAL+=("$1")
      shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

TARGET_DIR="${1:-.}"

# ================================ Sicherheitsprüfung ============================
if is_protected_dir "$TARGET_DIR" && ! $FORCE; then
  print_msg error "Systemverzeichnis erkannt: $TARGET_DIR. Mit -f erzwingen."
  exit 1
fi

# ================================ Hauptlogik ====================================
print_msg info "Starte Verarbeitung in: $TARGET_DIR (Tiefe: $DEPTH)"

# Finde Dateien und Verzeichnisse mit Leerzeichen
mapfile -t ITEMS < <(find "$TARGET_DIR" -mindepth 1 -maxdepth "$DEPTH" -name '* *')

if [[ ${#ITEMS[@]} -eq 0 ]]; then
  print_msg success "Keine Dateien oder Verzeichnisse mit Leerzeichen gefunden."
  exit 0
fi

for src in "${ITEMS[@]}"; do
  dir=$(dirname "$src")
  base=$(basename "$src")

  # Leerzeichen ersetzen oder entfernen
  if $REMOVE_SPACES; then
    newbase="${base// /}"
  else
    newbase="${base// /-}"
  fi
  dst="$dir/$newbase"

  # Überspringen, wenn Quelle und Ziel gleich
  [[ "$src" == "$dst" ]] && continue

  print_msg info "Alt: $src"
  print_msg info "Neu: $dst"

  # Bestätigung einholen, wenn nicht global bestätigt
  if ! $CONFIRM_ALL; then
    print_msg prompt "\nProcess this renaming? [y/n/a/q] (y=yes, n=no, a=yes to all, q=quit)"
    read -r choice
    case $choice in
      y|Y) ;;
      n|N) continue ;;
      a|A) CONFIRM_ALL=true ;;
      q|Q) exit 0 ;;
      *) continue ;;
    esac
  fi

  # Umbenennung
  if $DRY_RUN; then
    print_msg info "(Trockenlauf) mv \"$src\" \"$dst\""
  else
    if mv -v -- "$src" "$dst"; then
      print_msg success "Umbenannt: $dst"
    else
      print_msg error "Fehler beim Umbenennen: $src"
    fi
  fi

done

print_msg success "Verarbeitung abgeschlossen."
exit 0


