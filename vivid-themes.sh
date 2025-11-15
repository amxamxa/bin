#!/usr/bin/env bash
#
# Robustes Vivid Theme Preview Skript
#
# Dieses Skript iteriert interaktiv durch alle 'vivid' Themen
# mit verbesserter Benutzerfreundlichkeit und Fehlerbehandlung.

# --- Robustheit (Pkt 3.2): Strikter Modus ---
# set -e: Bricht sofort ab, wenn ein Befehl fehlschlägt.
# set -u: Behandelt nicht gesetzte Variablen als Fehler.
# set -o pipefail: Fehler in einer Pipeline (z.B. cmd1 | cmd2) werden weitergegeben.
set -euo pipefail

# --- Benutzerfreundlichkeit (Pkt 2.1): Farben und Symbole ---
# Verwendung von readonly, um Überschreiben zu verhindern.
# tput wird bevorzugt, wenn verfügbar, da es portabler ist als Hardcode-Escapes.
if command -v tput &>/dev/null && [[ -n "$(tput colors)" ]] && [[ "$(tput colors)" -ge 8 ]]; then
    readonly RESET="$(tput sgr0)"
    readonly GREEN="$(tput setaf 2)"
    readonly RED="$(tput setaf 1)"
    readonly YELLOW="$(tput setaf 3)"
    readonly BOLD="$(tput bold)"
else
    # Fallback auf ANSI-Escape-Codes, falls tput fehlschlägt
    readonly RESET='\033[0m'
    readonly GREEN='\033[0;32m'
    readonly RED='\033[0;31m'
    readonly YELLOW='\033[1;33m'
    readonly BOLD='\033[1m'
fi

# Symbole für klarere Ausgaben
readonly S_INFO="[ℹ️]"
readonly S_ERROR="[❌]"
readonly S_OK="[✅]"
readonly S_PROMPT="[▶️]"
readonly S_THEME="[🎨]"

# --- Konfiguration (Pkt 3.4): Timeout ---
# Dauer in Sekunden (Format für 'timeout'-Befehl)
readonly TIMEOUT_DURATION="5s"

# --- Robustheit (Pkt 3.3): Signalbehandlung ---
# Diese Funktion wird bei Skript-Ende (EXIT) oder Abbruch (INT, TERM) aufgerufen.
cleanup() {
    # Stellt sicher, dass der Cursor sichtbar ist, falls 'vivid preview' ihn versteckt
    # und bei einem Abbruch (Strg+C) nicht wiederherstellt.
    if command -v tput &>/dev/null; then
        tput cnorm # Cursor normal (sichtbar)
    fi
    # Setzt Terminalfarben auf den Standard zurück
    echo -e "$RESET"
    
    # Optional: Benachrichtigung über sauberes Beenden
    # echo "\n${S_INFO} Vorschau beendet."
}
# 'trap' fängt Signale ab und führt 'cleanup' aus.
# EXIT: Wird immer am Ende des Skripts ausgeführt (egal ob Fehler oder Erfolg).
# INT: (Interrupt) Signal von Strg+C.
# TERM: (Terminate) Signal, z.B. von 'kill'.
trap cleanup EXIT INT TERM

# --- Benutzerfreundlichkeit (Pkt 2.2): Hilfefunktion ---
usage() {
    # 'cat <<EOF' ist ein "Here Document", ideal für mehrzeilige Textblöcke.
    cat <<EOF
${BOLD}Vivid Theme Previewer${RESET}

Dieses Skript zeigt interaktiv eine Vorschau aller verfügbaren 'vivid'-Themen an.

${YELLOW}Funktionen:${RESET}
  - Iteriert durch alle Themen von \`vivid themes\`.
  - Zeigt eine farbige Vorschau mit Symbolen.
  - Wartet auf Benutzerbestätigung ([Enter]) vor dem nächsten Thema.
  - Implementiert robuste Fehlerbehandlung (\`set -euo pipefail\`).
  - Verwendet Timeouts ($TIMEOUT_DURATION) für \`vivid\`-Befehle, um Hängen zu verhindern.
  - Fängt Signale (z.B. Strg+C) für ein sauberes Beenden ab.

${YELLOW}Nutzung:${RESET}
  $0       ${GREEN}# Startet die interaktive Vorschau${RESET}
  $0 -h    ${GREEN}# Zeigt diese Hilfe an${RESET}
  $0 --help ${GREEN}# Zeigt diese Hilfe an${RESET}

${YELLOW}Voraussetzungen (Robustheit Pkt 3.1):${RESET}
  - \`vivid\` muss im PATH installiert sein.
  - \`timeout\` (Teil von GNU coreutils) muss im PATH installiert sein.
EOF
}

# --- Robustheitsprüfung (Pkt 3.1): Abhängigkeiten ---
# Prüft, ob die benötigten externen Befehle vorhanden sind.
check_dependencies() {
    local missing_dep=0
    # 'command -v' ist der POSIX-konforme Weg, um die Existenz eines Befehls zu prüfen.
    # '&>/dev/null' leitet STDOUT und STDERR ins Nichts um (wir brauchen nur den Exit-Code).
    if ! command -v vivid &>/dev/null; then
        echo -e "${S_ERROR} ${RED}Fehler: 'vivid' nicht im PATH gefunden.${RESET}"
        missing_dep=1
    fi
    if ! command -v timeout &>/dev/null; then
        echo -e "${S_ERROR} ${RED}Fehler: 'timeout' (coreutils) nicht im PATH gefunden.${RESET}"
        missing_dep=1
    fi
    
    # Wenn eine Abhängigkeit fehlt, wird das Skript mit Fehlercode 1 beendet.
    if (( missing_dep == 1 )); then
        echo -e "${S_INFO} ${YELLOW}Bitte die fehlenden Abhängigkeiten installieren.${RESET}"
        exit 1
    fi
}

# --- Hauptfunktion ---
# Kapselt die Logik in einer 'main'-Funktion (gute Praxis).
main() {
    # Argumenten-Parsing für die Hilfe
    # "${1-}" ist eine Shell-Parameter-Expansion, die 'unset' (keine Argumente) abfängt
    # und einen leeren String zurückgibt, was 'set -u' zufriedenstellt.
    if [[ "${1-}" == "-h" ]] || [[ "${1-}" == "--help" ]]; then
        usage
        exit 0
    fi

    # Führt die Abhängigkeitsprüfung aus
    check_dependencies
    echo -e "${S_OK} ${GREEN}Alle Abhängigkeiten (vivid, timeout) sind erfüllt.${RESET}"
    
    echo -e "${S_INFO} Lade 'vivid' Themen (Timeout: $TIMEOUT_DURATION)..."
    
    # Themen sicher in ein Array laden (Pkt 3.4)
    local -a themes
    # 'readarray -t' (oder 'mapfile -t') liest Zeilen in ein Array.
    # '< <(cmd)' (Process Substitution) ist robuster als 'cmd | readarray',
    # da es 'set -o pipefail' nicht fälschlicherweise auslöst, wenn 'timeout' erfolgreich ist.
    if ! readarray -t themes < <(timeout "$TIMEOUT_DURATION" vivid themes); then
        # Dieser Block wird ausgeführt, wenn 'timeout' oder 'vivid themes' fehlschlägt
        # (Dank 'set -e' würde das Skript sowieso abbrechen, dies gibt aber eine bessere Fehlermeldung)
        echo -e "${S_ERROR} ${RED}Fehler beim Abrufen der 'vivid' Themen.${RESET}"
        echo "Mögliche Ursachen: 'vivid themes' dauerte länger als $TIMEOUT_DURATION oder gab einen Fehler zurück."
        exit 1
    fi

    # Prüfen, ob überhaupt Themen gefunden wurden
    if (( ${#themes[@]} == 0 )); then
        echo -e "${S_ERROR} ${RED}Keine 'vivid' Themen gefunden.${RESET}"
        exit 1
    fi
    
    echo -e "${S_OK} ${GREEN}${_}#themes[@]} Themen gefunden. Starte Vorschau...${RESET}"
    sleep 1 # Kurze Pause, damit der Benutzer die Meldung lesen kann

    # --- Korrektur der 'read'-Syntax ---
    # Die Syntax 'read -r '?' (aus dem Beispiel) ist Zsh-spezifisch für den Prompt.
    # Die Bash-konforme Syntax verwendet '-p' (prompt).
    local prompt_msg
    prompt_msg="${S_PROMPT} ${YELLOW}Drücken Sie [Enter] für das nächste Thema (oder [Strg+C] zum Abbrechen):${RESET} "

    # --- Hauptschleife (Pkt 1) ---
    # Iteriert sicher über das Array. "${themes[@]}" stellt sicher, dass
    # Themen mit Leerzeichen korrekt behandelt werden.
    for theme in "${themes[@]}"; do
        clear 
        
        # (Pkt 2.1) Farbige Ausgabe mit Symbol
        # \t (Tabulator) für bessere Ausrichtung
        echo -e "${S_THEME} Vorschau für Thema: \t ${BOLD}${GREEN}$theme${RESET}"
        
        # (Pkt 3.4) Timeout für den Preview-Befehl
        # '|| true' wird hinzugefügt, falls 'vivid preview' einen Fehlercode zurückgibt
        # (z.B. wenn das Thema fehlerhaft ist), 'set -e' aber nicht die
        # gesamte Schleife abbrechen soll.
        if ! timeout "$TIMEOUT_DURATION" vivid preview "$theme"; then
            echo -e "\n${S_ERROR} ${RED}'vivid preview $theme' ist fehlgeschlagen oder hat das Zeitlimit ($TIMEOUT_DURATION) überschritten.${RESET}"
            # Das Skript fährt trotzdem mit dem nächsten Thema fort
        fi
        
        # (Pkt 2.2 / Korrektur) Warten auf Benutzer
        # -p für Prompt, -r für raw input (verhindert Backslash-Interpretation)
        read -r -p "$prompt_msg"
    done
    
    echo -e "\n${S_OK} ${GREEN}Alle Themen wurden angezeigt.${RESET}"
}

# --- Skriptausführung ---
# Übergibt alle Argumente ($@), die das Skript erhalten hat, an 'main'.
# Dies stellt sicher, dass './script.sh -h' funktioniert.
main "$@"

