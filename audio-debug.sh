#!/usr/bin/env bash
#
# debug-audio.sh — PipeWire/WirePlumber diagnostic collector for NixOS
#
# Purpose: Gathers a complete snapshot of the audio stack (PipeWire core,
# WirePlumber session manager, ALSA/USB/FireWire hardware layer, kernel
# messages, and realtime permissions) into a single timestamped log file.
# Read-only, no config changes. Safe to run repeatedly.
#
# Usage:
#   ./debug-audio.sh [-o|--output-dir DIR] [-h|--help]
#
# Exit codes:
#   0    success (report written, even if some tools were missing)
#   1    fatal error (no writable location / no core audio stack found)
#   2    invalid usage (bad argument)
#   130  interrupted by user (SIGINT/SIGTERM)

# --- guard: this script requires bash, not plain sh -----------------------
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Fehler: dieses Script benoetigt bash, nicht sh. Aufruf: bash $0" >&2
    exit 1
fi

set -uo pipefail
# NOTE: '-e' is intentionally NOT set. A single missing tool or a failing
# diagnostic command must never abort the whole run — every section should
# still produce output even if earlier sections failed.

# --- globals ----------------------------------------------------------
SCRIPT_NAME="$(basename "$0")"
VERSION="0.2"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTDIR="."                     # relative by default -> file lands in cwd, no subfolder created
LOGFILE=""                     # resolved after argument parsing
INTERRUPTED=0
WARNINGS=0
SKIPPED=0

# Tools used by this script, mapped to the Nix package that provides them.
declare -A TOOL_PKG=(
    [pw-cli]="pipewire"
    [pw-top]="pipewire"
    [pw-metadata]="pipewire"
    [pw-dump]="pipewire"
    [pw-link]="pipewire"
    [wpctl]="wireplumber"
    [pactl]="pipewire (pipewire-pulse Modul aktivieren)"
    [aplay]="alsa-utils"
    [arecord]="alsa-utils"
    [lsusb]="usbutils"
    [ffado-test]="ffado (nur noetig fuer FireWire-Interfaces)"
    [journalctl]="systemd (Kernbestandteil)"
    [systemctl]="systemd (Kernbestandteil)"
    [loginctl]="systemd (Kernbestandteil)"
    [nixos-version]="nixos (Kernbestandteil)"
    [nix-store]="nix (Kernbestandteil)"
)
# Tools without which a meaningful report is essentially impossible.
CORE_TOOLS=(pw-cli wpctl pactl)
MISSING_TOOLS=()

# --- help ---------------------------------------------------------------
print_help() {
    cat <<EOF
${SCRIPT_NAME} v${VERSION} — PipeWire/WirePlumber Diagnose-Sammler fuer NixOS

Sammelt Status von PipeWire, WirePlumber, ALSA, USB- und FireWire-Audio-
Hardware sowie relevante Kernel-/Service-Logs in einer einzigen Logdatei.
Rein lesend, keine Aenderungen am System.

VERWENDUNG:
    ${SCRIPT_NAME} [OPTIONEN]

OPTIONEN:
    -o, --output-dir DIR   Zielverzeichnis fuer die Logdatei
                           (Standard: aktuelles Verzeichnis, "." — es wird
                           KEIN Unterordner angelegt)
    -h, --help             Diese Hilfe anzeigen und beenden

BEISPIELE:
    ${SCRIPT_NAME}
        -> schreibt ./audio-debug-<timestamp>.log

    ${SCRIPT_NAME} -o /tmp
        -> schreibt /tmp/audio-debug-<timestamp>.log

EXIT-CODES:
    0    Erfolg (Report geschrieben, auch wenn einzelne Tools fehlten)
    1    Fataler Fehler (kein Schreibzugriff / PipeWire komplett fehlend)
    2    Ungueltiger Aufruf
    130  Durch Nutzer abgebrochen (Strg+C)
EOF
}

# --- argument parsing -----------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        -o|--output-dir)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "Fehler: ${1} benoetigt ein Verzeichnis als Argument." >&2
                exit 2
            fi
            OUTDIR="$2"
            shift 2
            ;;
        *)
            echo "Fehler: unbekannte Option '$1'" >&2
            echo "Aufruf: ${SCRIPT_NAME} --help" >&2
            exit 2
            ;;
    esac
done

# --- signal handling --------------------------------------------------
on_interrupt() {
    INTERRUPTED=1
    echo >&2
    echo "[Abbruch] Signal empfangen — Teil-Report wird trotzdem gesichert." >&2
    exit 130
}
trap on_interrupt INT TERM

on_exit() {
    local code=$?
    if [ -n "$LOGFILE" ] && [ -f "$LOGFILE" ]; then
        if [ "$INTERRUPTED" -eq 1 ]; then
            echo "Script unterbrochen. Bisheriger Report: ${LOGFILE}" >&2
        fi
        {
            echo
            echo "=================================================================="
            echo " Zusammenfassung"
            echo "=================================================================="
            echo "Fehlende Tools : ${#MISSING_TOOLS[@]} (${MISSING_TOOLS[*]:-keine})"
            echo "Warnungen      : ${WARNINGS}"
            echo "Uebersprungen  : ${SKIPPED}"
            echo "Exit-Code      : ${code}"
        } >>"$LOGFILE" 2>/dev/null || true
    fi
    return 0
}
trap on_exit EXIT

die() {
    echo "Fataler Fehler: $1" >&2
    exit 1
}

# --- resolve output location, with fallback ----------------------------
resolve_logfile() {
    # normalize: default "." means "no subfolder", just a bare filename
    if [ "$OUTDIR" = "." ]; then
        LOGFILE="audio-debug-${TIMESTAMP}.log"
    else
        # create the directory only if the user explicitly asked for one
        if [ ! -d "$OUTDIR" ]; then
            mkdir -p "$OUTDIR" 2>/dev/null || {
                echo "Warnung: Verzeichnis '${OUTDIR}' konnte nicht angelegt werden, weiche auf '.' aus." >&2
                OUTDIR="."
                LOGFILE="audio-debug-${TIMESTAMP}.log"
                return
            }
        fi
        LOGFILE="${OUTDIR%/}/audio-debug-${TIMESTAMP}.log"
    fi

    # writability check with graceful fallback to /tmp
    if ! ( : >"$LOGFILE" ) 2>/dev/null; then
        echo "Warnung: '${LOGFILE}' ist nicht beschreibbar, weiche auf /tmp aus." >&2
        LOGFILE="/tmp/audio-debug-${TIMESTAMP}.log"
        if ! ( : >"$LOGFILE" ) 2>/dev/null; then
            die "auch /tmp ist nicht beschreibbar — kein Zielort fuer den Report gefunden."
        fi
    fi
}

# --- dependency check ---------------------------------------------------
check_dependencies() {
    local tool pkg status
    {
        echo "### Werkzeug-Verfuegbarkeit"
        printf '%-14s %-8s %s\n' "TOOL" "STATUS" "NIX-PAKET (falls fehlend)"
    } >>"$LOGFILE"

    for tool in "${!TOOL_PKG[@]}"; do
        pkg="${TOOL_PKG[$tool]}"
        if command -v "$tool" >/dev/null 2>&1; then
            status="ok"
        else
            status="FEHLT"
            MISSING_TOOLS+=("$tool")
        fi
        printf '%-14s %-8s %s\n' "$tool" "$status" "$pkg" >>"$LOGFILE"
    done
    echo >>"$LOGFILE"

    if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
        echo "Hinweis: ${#MISSING_TOOLS[@]} Tool(s) fehlen: ${MISSING_TOOLS[*]}" >&2
        echo "         In configuration.nix ergaenzen, z.B. via environment.systemPackages." >&2
    fi

    # Fatal only if NONE of the core PipeWire tools are present at all —
    # in that case a "report" would be empty and misleading.
    local core_found=0
    for tool in "${CORE_TOOLS[@]}"; do
        command -v "$tool" >/dev/null 2>&1 && core_found=1
    done
    if [ "$core_found" -eq 0 ]; then
        die "keines der Kern-Tools (${CORE_TOOLS[*]}) ist installiert — PipeWire scheint nicht vorhanden zu sein."
    fi
}

# --- environment sanity (things that silently break systemctl --user etc.) -
preflight_warnings() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "Warnung: Script laeuft als root — 'systemctl --user' und 'pactl' greifen dann" >&2
        echo "         auf die root-Session zu, nicht auf die des Desktop-Users." >&2
    fi
    if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -d "${XDG_RUNTIME_DIR:-/nonexistent}" ]; then
        echo "Warnung: XDG_RUNTIME_DIR ist nicht gesetzt oder existiert nicht —" >&2
        echo "         PipeWire-/WirePlumber-Abfragen liefern dann evtl. keine Ergebnisse." >&2
    fi
}

# --- runner helpers -----------------------------------------------------

# Runs a real command (argv form). Captures output + exit status, never
# lets a failure propagate to the caller.
run() {
    local title="$1"
    shift
    {
        echo "### ${title}"
        echo "\$ $*"
        if ! command -v "$1" >/dev/null 2>&1; then
            echo "[uebersprungen] Befehl nicht gefunden: $1"
            SKIPPED=$((SKIPPED + 1))
        else
            if ! "$@" 2>&1; then
                echo "[warnung] Befehl endete mit Exit-Code $?"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
        echo
    } >>"$LOGFILE" 2>&1
}

# Runs a shell snippet (pipelines, globs, redirections). Exit status of
# pipelines (e.g. grep finding nothing) is informational only, NOT counted
# as a warning, since "no matches" is a normal, expected outcome.
run_raw() {
    local title="$1"
    local cmd="$2"
    {
        echo "### ${title}"
        echo "\$ ${cmd}"
        eval "$cmd" 2>&1
        echo
    } >>"$LOGFILE" 2>&1
}

section() {
    {
        echo
        echo "=================================================================="
        echo " $1"
        echo "=================================================================="
    } >>"$LOGFILE"
}

# =========================================================================
# main
# =========================================================================

resolve_logfile
{
    echo "PipeWire/WirePlumber Audio Debug Report"
    echo "Generated: $(date -Iseconds)"
    echo "Host: $(hostname 2>/dev/null || echo unbekannt)"
    echo "Script-Version: ${VERSION}"
} >>"$LOGFILE"

section "0. Vorabpruefung"
check_dependencies
preflight_warnings

# 1. System / NixOS baseline --------------------------------------------
section "1. System & NixOS Baseline"
run "Kernel version"        uname -a
run "NixOS version"         nixos-version
run_raw "PipeWire-relevante NixOS-Config-Zeilen" \
    "grep -n -E 'pipewire|wireplumber|jack|rtkit|realtime' /etc/nixos/configuration.nix 2>/dev/null || echo '[info] configuration.nix hier nicht lesbar'"
run_raw "Nix-installiertes pipewire-Paket" \
    "nix-store -q --requisites /run/current-system 2>/dev/null | grep -i pipewire | head -20"

# 2. Service status ------------------------------------------------------
section "2. Systemd Service-Status (User + RTKit)"
run "PipeWire service"          systemctl --user status pipewire.service --no-pager -l
run "PipeWire-Pulse service"    systemctl --user status pipewire-pulse.service --no-pager -l
run "WirePlumber service"       systemctl --user status wireplumber.service --no-pager -l
run "RTKit daemon (system)"     systemctl status rtkit-daemon.service --no-pager -l
run "Alle aktiven pipewire-Units" systemctl --user list-units --all --no-pager

# 3. PipeWire core --------------------------------------------------------
section "3. PipeWire Core"
run "pw-cli info"      pw-cli info
run "pw-cli ls (alle Objekte)"  pw-cli ls
run "pw-cli ls Node"   pw-cli ls Node
run "pw-cli ls Device" pw-cli ls Device
run "pw-link (Graph-Verbindungen)" pw-link -l

# pw-top is a live TUI without a documented non-interactive/batch flag;
# capture a short timed sample instead of hanging the whole script.
run_raw "pw-top Snapshot (2s Sample)" \
    "timeout 2 pw-top -b 2>/dev/null || echo '[hinweis] pw-top hat keinen verlaesslichen Batch-Modus in dieser Version; manuell ausfuehren: pw-top'"

# 4. WirePlumber / session policy ----------------------------------------
section "4. WirePlumber Session Manager"
run "wpctl status (Geraetebaum, Lautstaerken, Defaults)" wpctl status
run "pw-metadata -n settings (Clock-/Quantum-Policy)" pw-metadata -n settings
run_raw "pw-dump default.clock Abschnitt" \
    "pw-dump 2>/dev/null | grep -A5 'default.clock'"
run_raw "pw-dump Sample-Rate/Quantum" \
    "pw-dump 2>/dev/null | grep -E 'clock.rate|clock.quantum|clock.force-quantum'"

# 5. PulseAudio compatibility layer ---------------------------------------
section "5. PulseAudio-Kompatibilitaetsschicht"
run "pactl info"                   pactl info
run "pactl list short cards"       pactl list short cards
run "pactl list short sinks"       pactl list short sinks
run "pactl list short sources"     pactl list short sources
run "pactl list cards (ausfuehrlich, Profile)" pactl list cards

# 6. ALSA hardware layer --------------------------------------------------
section "6. ALSA Hardware-Ebene"
run "aplay -l (Wiedergabegeraete)"  aplay -l
run "arecord -l (Aufnahmegeraete)" arecord -l
run_raw "/proc/asound/cards"    "cat /proc/asound/cards"
run_raw "/proc/asound/modules"  "cat /proc/asound/modules"
run_raw "Geladene ALSA/Sound-Kernelmodule" "lsmod | grep -iE 'snd|bebob|firewire'"
run_raw "Karten-Device-Symlinks (Bus-Zuordnung)" \
    "for d in /sys/class/sound/card*/device; do [ -e \"\$d\" ] && echo \"\$d -> \$(readlink -f \"\$d\")\"; done"

# 7. USB audio & power management -----------------------------------------
section "7. USB-Audiogeraete & Autosuspend"
run "lsusb (alle USB-Geraete)" lsusb
run_raw "USB-Autosuspend, globaler Default" \
    "cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null || echo '[info] Parameter nicht verfuegbar'"
run_raw "USB Per-Device power/control Status" \
    "for f in /sys/bus/usb/devices/*/power/control; do [ -f \"\$f\" ] && echo \"\$f: \$(cat \"\$f\")\"; done"
run_raw "USB-Geraete mit Produktnamen (z.B. Scarlett identifizieren)" \
    "for f in /sys/bus/usb/devices/*/product; do [ -f \"\$f\" ] && echo \"\$f: \$(cat \"\$f\")\"; done"

# 8. FireWire audio (BeBoB / FFADO) ----------------------------------------
section "8. FireWire-Audio (snd_bebob / FFADO)"
run_raw "FireWire-Kernelmodule geladen" "lsmod | grep -iE 'firewire|bebob'"
run_raw "FireWire-Device-Nodes" "ls -l /dev/fw* 2>/dev/null || echo '[info] keine /dev/fw*-Nodes vorhanden'"
run "ffado-test ListDevices" ffado-test ListDevices
run_raw "journalctl: FireWire/BeBoB Boot-Meldungen" \
    "journalctl -k -b 2>/dev/null | grep -Ei 'firewire|bebob|1394' | tail -50"

# 9. Kernel & service logs --------------------------------------------------
section "9. Kernel- & Service-Logs"
run_raw "journalctl -k -b: usb/xhci/focusrite/snd" \
    "journalctl -k -b 2>/dev/null | grep -Ei 'usb|xhci|focusrite|snd' | tail -100"
run_raw "journalctl --user -u pipewire (Warnungen/Fehler)" \
    "journalctl --user -u pipewire --no-pager -p warning -b 2>/dev/null | tail -50"
run_raw "journalctl --user -u wireplumber (Warnungen/Fehler)" \
    "journalctl --user -u wireplumber --no-pager -p warning -b 2>/dev/null | tail -50"

# 10. Realtime scheduling & permissions -------------------------------------
section "10. Realtime-Scheduling & Berechtigungen"
run_raw "Gruppenmitgliedschaften (relevant: audio, ggf. realtime)" "groups"
run_raw "RT-/Memlock-Limits des aktuellen Users" "ulimit -a"
run_raw "Systemweite RT-Limits (limits.d)" \
    "cat /etc/security/limits.d/*.conf 2>/dev/null || echo '[info] keine Drop-in Limits-Dateien (NixOS setzt dies ueber security.rtkit/pam)'"
run "RTKit-Session via loginctl" loginctl show-session self -p RuntimeMax

# 11. Environment sanity -----------------------------------------------------
section "11. Umgebungs-Check"
run_raw "XDG_RUNTIME_DIR Inhalt" \
    "ls -l \"\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}\" 2>/dev/null || echo '[warnung] XDG_RUNTIME_DIR nicht zugreifbar'"
run_raw "PipeWire-/WirePlumber-relevante Env-Variablen" \
    "env | grep -E 'PIPEWIRE_|WIREPLUMBER_|XDG_RUNTIME_DIR|JACK_' || echo '[info] keine gesetzt'"

echo "Fertig. Report gespeichert unter: ${LOGFILE}" >&2
echo "$LOGFILE"
exit 0

