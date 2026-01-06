#!/usr/bin/env bash

# # $XDG_VIDEOS_DIR #$XDG_MUSIC_DIR
#Wählbarer Download-Ordner
 #   DEFAULT-WERT $XGD_VIDEOS
 #  Eingabeaufforderung
 # Fehlt der Ordner → automatische Erstellung
 # Fehlerschutz bei fehlenden Rechten

# Automatische, konfliktfreie Dateinamen
 #   yt-dlp-Template:
 #  %(title).150s.%(ext)s
 # --no-overwrites schützt vor Überschreiben
 # --restrict-filenames entfernt problematische Zeichen

# Fortschrittsanzeige
 #   yt-dlp zeigt automatisch eine präzise Fortschrittsleiste
  #  kein weiterer Code nötig

#Fehlerhandling
 #   Prüfung von $?
 #  klare Fehlermeldung
  # Exit-Code wird korrekt durchgereicht
#--------------------------------------------------------

# kompaktes, zuverlässiges Bash-Skript, das YouTube-Links als mp3 (Musik), mp4 (Video) per yt-dlp herunterlädt. 
#F unktionsaufruf ohne Argument fragt YouTube-URL ab und beim Start nach Modus (mp3 oder mp4) fragt.

#t odo - YouTube Downloader for NixOS
# Requirements: yt-dlp, ffmpeg

# Color definitions

SKY="\033[38;2;62;36;129m\033[48;2;135;206;235m"
MINT="\033[38;2;6;88;96m\033[48;2;144;238;144m"
NIGHT="\033[38;2;252;222;90m\033[48;2;0;0;139m"
RED="\033[38;2;240;128;128m\033[48;2;139;0;0m"
RASPBERRY="\033[38;2;32;0;21m\033[48;2;221;160;221m"
PINK="\033[38;2;32;0;21m\033[48;2;163;64;217m"
VIOLETT="\033[38;2;255;0;53m\033[48;2;34;0;82m"
ORA="\033[38;2;0;17;204m\033[48;2;255;140;0m"
CYAN="\033[38;2;0;0;0m\033[48;2;0;255;255m"
GREEN="\033[38;2;0;50;0m\033[48;2;144;238;144m"
YELLOW="\033[38;2;139;69;19m\033[48;2;255;255;0m"
RESET="\033[0m"

# ASCII Art Header
printf "%s" "$VIOLETT"
cat <<'EOF'
  `YMM'   `MM'                 
    VMA   ,V                   
     VMA ,V ,pW"Wq.`7MM  `7MM  
      VMMP 6W'   `Wb MM    MM  
       MM  8M     M8 MM    MM  
       MM  YA.   ,A9 MM    MM  
     .JMML. `Ybmd9'  `Mbod"YML.                                      
                
 MMP""MM""YMM       *MM                 
 P'   MM   `7        MM                 
      MM `7MM  `7MM  MM,dMMb.   .gP"Ya  
      MM   MM    MM  MM    `Mb ,M'   Yb 
      MM   MM    MM  MM     M8 8M=`=`=`= 
      MM   MM    MM  MM.   ,M9 YM.    , 
    .JMML. `Mbod"YML.P^YbmdP'   `Mbmmd'                                   

EOF
printf "%s" "$RESET"

printf "%s" "$NIGHT"
cat <<'EOF'

     8888b.   dP"Yb  Yb        dP 88b 88 
     8I  Yb dP   Yb  Yb  db  dP  88Yb88 
     8I  dY Yb   dP   YbdPYbdP   88 Y88 
     8888Y"   YbodP     YP  YP    88  Y8 
88      dP"Yb     db    8888b.  888888 88""Yb 
88     dP   Yb   dPYb    8I  Yb 88__   88__dP 
88  .o Yb   dP  dP__Yb   8I  dY 88""   88"Yb  
88ood8  YbodP  dP""""Yb 8888Y"  888888 88  Yb 

EOF
printf "%s" "$RESET"
echo -e "${RASPBERRY}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${RASPBERRY}║${RESET}  ${PINK}amxamxs${RESET} ${MINT}aka${RESET} ${CYAN}YouTube Downloader${RESET}              ${RASPBERRY}║${RESET}"
echo -e "${RASPBERRY}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

# --- URL Input ----------------------------------------------------
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│${RESET} ${ORA}URL eingeben:${RESET}                                    ${CYAN}│${RESET}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
printf "${GREEN}➜${RESET} "
read -r URL
if [[ -z "$URL" ]]; then
    echo -e "${RED}✗ Keine URL angegeben. Abbruch.${RESET}"
    exit 1
fi

# --- Mode Selection -----------------------------------------------
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│${RESET} ${ORA}Modus auswählen:${RESET}                                 ${CYAN}│${RESET}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${MINT}1)${RESET} ${PINK}MP3${RESET} - Audio mit 192 kbps"
echo -e "  ${MINT}2)${RESET} ${PINK}MP4${RESET} - Video mit Audio"
echo -e "  ${MINT}3)${RESET} ${RED}Exit${RESET}"
echo ""
printf "${GREEN}➜${RESET} Auswahl [1-3]: "
read -r MODE_CHOICE

case "$MODE_CHOICE" in
    1)
        echo -e "${GREEN}✓${RESET} ${PINK}MP3-Modus${RESET} gewählt"
        FORMAT="bestaudio/best"
        OUTTPL="%(title).150s.%(ext)s"
        EXTRA_OPTS="-x --audio-format mp3 --audio-quality 192k"
        DEFAULT_DIR="${XDG_MUSIC_DIR:-$HOME/Music}"
        ;;
    2)
        echo -e "${GREEN}✓${RESET} ${PINK}MP4-Modus${RESET} gewählt"
        FORMAT="bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        OUTTPL="%(title).150s.%(ext)s"
        EXTRA_OPTS="--merge-output-format mp4"
        DEFAULT_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}"
        ;;
    3)
        echo -e "${YELLOW}Exit.${RESET}"
        exit 0
        ;;
    *)
        echo -e "${RED}✗ Ungültige Auswahl.${RESET}"
        exit 1
        ;;
esac

# --- Download Directory -------------------------------------------
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│${RESET} ${ORA}Download-Ordner:${RESET}                                 ${CYAN}│${RESET}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${MINT}Standard:${RESET} $DEFAULT_DIR"
printf "${GREEN}➜${RESET} Pfad (Enter = Standard): "
read -r DL_DIR

if [[ -z "$DL_DIR" ]]; then
    DL_DIR="$DEFAULT_DIR"
fi

if [[ ! -d "$DL_DIR" ]]; then
    echo -e "${YELLOW}⚠ Ordner existiert nicht. Erstelle: $DL_DIR${RESET}"
    mkdir -p "$DL_DIR" || {
        echo -e "${RED}✗ Konnte Ordner nicht erstellen.${RESET}"
        exit 1
    }
    echo -e "${GREEN}✓${RESET} Ordner erstellt"
fi

# --- Additional Options -------------------------------------------
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│${RESET} ${ORA}Zusätzliche Optionen:${RESET}                            ${CYAN}│${RESET}"
echo -e "${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${MINT}1)${RESET} Standard (Thumbnail + Metadata)"
echo -e "  ${MINT}2)${RESET} + SponsorBlock (entfernt Sponsor-Segmente)"
echo -e "  ${MINT}3)${RESET} + Browser-Cookies (Firefox)"
echo -e "  ${MINT}4)${RESET} + Alle Optionen"
echo ""
printf "${GREEN}➜${RESET} Auswahl [1-4]: "
read -r OPT_CHOICE

ADDITIONAL_OPTS=""
case "$OPT_CHOICE" in
    1)
        echo -e "${GREEN}✓${RESET} Standard-Optionen"
        ;;
    2)
        echo -e "${GREEN}✓${RESET} Mit SponsorBlock"
        ADDITIONAL_OPTS="--sponsorblock-remove all"
        ;;
    3)
        echo -e "${GREEN}✓${RESET} Mit Browser-Cookies"
        ADDITIONAL_OPTS="--cookies-from-browser firefox"
        ;;
    4)
        echo -e "${GREEN}✓${RESET} Alle Optionen aktiviert"
        ADDITIONAL_OPTS="--sponsorblock-remove all --cookies-from-browser firefox"
        ;;
    *)
        echo -e "${YELLOW}⚠ Ungültige Auswahl, verwende Standard${RESET}"
        ;;
esac

# --- Download Execution -------------------------------------------
echo ""
echo -e "${RASPBERRY}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${RASPBERRY}║${RESET}  ${GREEN}Download startet...${RESET}                            ${RASPBERRY}║${RESET}"
echo -e "${RASPBERRY}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

yt-dlp \
    -f "$FORMAT" \
    $EXTRA_OPTS \
    --embed-thumbnail \
    --embed-metadata \
    --add-metadata \
    --no-overwrites \
    --restrict-filenames \
    $ADDITIONAL_OPTS \
    --output "$DL_DIR/$OUTTPL" \
    "$URL"

STATUS=$?

# --- Error Handling -----------------------------------------------
echo ""
echo -e "${RASPBERRY}╔════════════════════════════════════════════════════╗${RESET}"
if (( STATUS != 0 )); then
    echo -e "${RASPBERRY}║${RESET}  ${RED}✗ Fehler beim Download (exit code $STATUS)${RESET}       ${RASPBERRY}║${RESET}"
    echo -e "${RASPBERRY}╚════════════════════════════════════════════════════╝${RESET}"
    echo -e "${YELLOW}⚠ Prüfe:${RESET}"
    echo -e "  • URL korrekt?"
    echo -e "  • Netzwerkverbindung aktiv?"
    echo -e "  • yt-dlp aktuell? (yt-dlp -U)"
    exit $STATUS
fi

echo -e "${RASPBERRY}║${RESET}  ${GREEN}✓ Download erfolgreich abgeschlossen!${RESET}            ${RASPBERRY}║${RESET}"
echo -e "${RASPBERRY}╚════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📁 Datei gespeichert in:${RESET}"
echo -e "   ${MINT}$DL_DIR${RESET}"
echo ""


