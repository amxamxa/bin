#!/usr/bin/env zsh

autoload -U colors && colors

print -P "%F{cyan}YouTube Downloader%f"

# --- URL ----------------------------------------------------------
print -n "URL: "
read URL
if [[ -z "$URL" ]]; then
    print -P "%F{red}Keine URL angegeben. Abbruch.%f"
    exit 1
fi

# --- Download-Ordner ---------------------------------------------
print -n "Download-Ordner (Enter = aktueller): "
read DL_DIR

if [[ -z "$DL_DIR" ]]; then
    DL_DIR="$PWD"
fi

if [[ ! -d "$DL_DIR" ]]; then
    print -P "%F{yellow}Ordner existiert nicht. Erstelle: $DL_DIR%f"
    mkdir -p "$DL_DIR" || {
        print -P "%F{red}Konnte Ordner nicht erstellen.%f"
        exit 1
    }
fi

# --- Menü ---------------------------------------------------------
print -P "\nModus auswählen:"
select MODE in \
    "Video (beste Qualität)" \
    "MP3 (nur Audio)" \
    "MP4 (Video+Audio mp4)" \
    "Exit"
do
    case "$REPLY" in
        1)  
            FORMAT="bestvideo+bestaudio/best"
            OUTTPL="%(title).150s.%(ext)s"
            break
            ;;
        2)  
            FORMAT="bestaudio"
            OUTTPL="%(title).150s.mp3"
            EXTRA_OPTS="-x --audio-format mp3"
            break
            ;;
        3)  
            FORMAT="bestvideo[ext=mp4]+bestaudio[ext=m4a]/best"
            OUTTPL="%(title).150s.%(ext)s"
            break
            ;;
        4)
            print "Exit."
            exit 0
            ;;
        *)
            print -P "%F{yellow}Ungültige Auswahl.%f"
            ;;
    esac
done

# --- Download -----------------------------------------------------
print -P "%F{blue}Starte Download...%f"

yt-dlp \
    -f "$FORMAT" \
    ${EXTRA_OPTS:-} \
    --no-overwrites \
    --restrict-filenames \
    --output "$DL_DIR/$OUTTPL" \
    "$URL"

STATUS=$?

# --- Fehlerhandling ----------------------------------------------
if (( STATUS != 0 )); then
    print -P "%F{red}Fehler beim Download (exit code $STATUS).%f"
    print -P "%F{yellow}Bitte prüfe die URL, Netzwerkverbindung oder yt-dlp-Version.%f"
    exit $STATUS
fi

print -P "%F{green}Download erfolgreich abgeschlossen.%f"
print -P "%F{cyan}Datei gespeichert in:%f $DL_DIR"

*/
1. Wählbarer Download-Ordner
    Eingabeaufforderung
    Fehlt der Ordner → automatische Erstellung
    Fehlerschutz bei fehlenden Rechten

2. Automatische, konfliktfreie Dateinamen
    yt-dlp-Template:
    %(title).150s.%(ext)s
    --no-overwrites schützt vor Überschreiben
    --restrict-filenames entfernt problematische Zeichen

3. Fortschrittsanzeige
    yt-dlp zeigt automatisch eine präzise Fortschrittsleiste
    kein weiterer Code nötig

4. Fehlerhandling
    Prüfung von $?
    klare Fehlermeldung
    Exit-Code wird korrekt durchgereicht

*/

