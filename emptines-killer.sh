#!/usr/bin/env bash
# ==============================================
# SPACE-TO-DASH CONVERTER
# A script to replace spaces with dashes in filenames and directories.
# Features:
# - Dry-run mode (preview changes)
# - Interactive confirmation
# - Configurable directory depth for grouping
# - Colored terminal output
# - Safe handling of special characters
# ==============================================

# ----------------------------
# COLOR DEFINITIONS (ANSI ESCAPE CODES)
# ----------------------------
RESET="\e[0m"               	   	   # Reset all formatting
COLOR_DRY_RUN="\033[38;2;255;200;0m"   # Yellow for dry-run
COLOR_SUCCESS="\033[38;2;0;255;0m"     # Green for success
COLOR_ERROR="\033[38;2;255;50;50m"     # Red for errors
COLOR_PROMPT="\033[38;2;100;149;237m"  # Blue for prompts
COLOR_INFO="\033[38;2;200;200;200m"    # Gray for info

# ----------------------------
# CONFIGURABLE SETTINGS (DEFAULTS)
# ----------------------------
GROUP_DEPTH=3                   # Ab diesem Verzeichnislevel gruppieren
FILES_PER_PROMPT=10             # Max. Dateien pro Abfrage
SHOW_FULL_PATHS=false           # Komplette Pfade anzeigen?

# ----------------------------
# FUNKTION: Farbige Ausgabe
# Usage: _print_msg [TYPE] "Nachricht"
# ----------------------------
_print_msg() {
    local type="$1"
    local msg="$2"
    local color=""

    case "$type" in
        "dryrun") color="${COLOR_DRY_RUN}" ;;
        "success") color="${COLOR_SUCCESS}" ;;
        "error") color="${COLOR_ERROR}" ;;
        "prompt") color="${COLOR_PROMPT}" ;;
        "group") color="${COLOR_GROUP}" ;;
        *) color="${RESET}" ;;
    esac

    echo -e "${color}${msg}${RESET}"
}

# ----------------------------
# FUNKTION: Gruppierte Dry-Run-Vorschau
# ----------------------------
_preview_grouped() {
    local current_group=""
    local counter=0
    local group_counter=0

    while read -r filepath; do
        # Bestimme Gruppenschlüssel (z.B. "Projekte/Mein-Projekt")
        local group_key=$(echo "$filepath" | cut -d'/' -f1-${GROUP_DEPTH} | tr ' ' '-')
        
        # Neue Gruppe beginnen
        if [[ "$group_key" != "$current_group" ]]; then
            current_group="$group_key"
            ((group_counter++))
            _print_msg "group" "\n--- Gruppe ${group_counter}: ${group_key} ---"
        fi

        # Dateipfad anpassen (gruppiert/komplett)
        if [ "$SHOW_FULL_PATHS" = true ]; then
            local display_path="$filepath"
            local display_new_path=$(echo "$filepath" | tr ' ' '-')
        else
            local display_path=$(echo "$filepath" | cut -d'/' -f${GROUP_DEPTH}-)
            local display_new_path=$(echo "$filepath" | tr ' ' '-' | cut -d'/' -f${GROUP_DEPTH}-)
        fi

        _print_msg "dryrun" "[${counter}] ${display_path} → ${display_new_path}"
        ((counter++))

        # Interaktive Abfrage nach jeder Gruppe
        if (( counter % FILES_PER_PROMPT == 0 )) || [[ -z $(peek_next_line) ]]; then
            _ask_for_execution
        fi
    done < <(find . -name "* *" -print | sort)
}

# ----------------------------
# HELFER: Prüft nächste Zeile ohne Verbrauch
# ----------------------------
peek_next_line() {
    IFS= read -r next_line
    printf '%s\n' "$next_line"
}

# ----------------------------
# FUNKTION: Frage nach Ausführung für aktuelle Gruppe
# ----------------------------
_ask_for_execution() {
    _print_msg "prompt" "\nDiese Gruppe umbenennen? (j/N/alle/exit) "
    read -r -n 1 response
    echo  # Neue Zeile

    case "$response" in
        [jJ]) _execute_single_group ;;
        [aA]) _execute_all_remaining ;;
        [eE]) _print_msg "info" "Abbruch durch Benutzer."; exit 0 ;;
        *) _print_msg "info" "Übersprungen." ;;
    esac
}

# ----------------------------
# FUNKTION: Benenne aktuelle Gruppe um
# ----------------------------
_execute_single_group() {
    find . -name "* *" -print0 | while IFS= read -r -d '' filepath; do
        local group_key=$(echo "$filepath" | cut -d'/' -f1-${GROUP_DEPTH} | tr ' ' '-')
        if [[ "$group_key" == "$current_group" ]]; then
            mv -v "$filepath" "$(echo "$filepath" | tr ' ' '-')"
        fi
    done
}

# ----------------------------
# HAUPTLOGIK
# ----------------------------
main() {
    _print_msg "info" "=== START: Leerzeichen-zu-Bindestrich-Konvertierung ==="
    _preview_grouped
    _print_msg "success" "=== VORGANG ABGESCHLOSSEN ==="
}

main "$@"

