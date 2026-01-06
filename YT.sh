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

# ASCII Art Header
# #!/usr/bin/env bash# # auth: max_kempter
cat <<-EOF                                                ${PINK}
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
$RESET
EOF
echo -e "${BLUE}... ... d o w n l o a d e r"
echo -e "${LIL2}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${LIL2}║${RESET}  ${PINK}amxamxs${RESET} ${MINT}aka${RESET} ${GREEN}YouTube Downloader${RESET}              ${LIL2}║${RESET}"
echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

# --- URL Input ----------------------------------------------------
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│${RESET} ${ORA}URL eingeben:${RESET}                                    ${CYAN}│${RESET}"
echo -e "${LIL"}└─────────────────────────────────────────────────────┘${RESET}"
printf "${GREEN}➜${RESET} "
read -r URL
if [[ -z "$URL" ]]; then
    echo -e "${RED}✗ Keine URL angegeben. Abbruch.${RESET}"
    exit 1
fi

# --- Mode Selection -----------------------------------------------
echo ""
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│${RESET} ${ORA}Modus auswählen:${RESET}                                 ${CYAN}│${RESET}"
echo -e "${LIL}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${LILA}1)${RESET} ${PINK}MP3${RESET} - Audio mit 192 kbps"
echo -e "  ${LIL2}2)${RESET} ${PINK}MP4${RESET} - Video mit Audio"
echo -e "  ${LILA}3)${RESET} ${RED}Exit${RESET}"
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
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${LIL2}│${RESET} ${ORA}Download-Ordner:${RESET}                                 ${LIL2}│${RESET}"
echo -e "${LIL2}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${BLUE}Standard:${RESET} $DEFAULT_DIR"
printf "${GREEN}➜${RESET} Pfad (Enter = Standard): "
read -r DL_DIR

if [[ -z "$DL_DIR" ]]; then
    DL_DIR="$DEFAULT_DIR"
fi

if [[ ! -d "$DL_DIR" ]]; then
    echo -e "${PINK}⚠ Ordner existiert nicht. Erstelle: $DL_DIR${RESET}"
    mkdir -p "$DL_DIR" || {
        echo -e "${RED}✗ Konnte Ordner nicht erstellen.${RESET}"
        exit 1
    }
    echo -e "${GREEN}✓${RESET} Ordner erstellt"
fi

# --- Additional Options -------------------------------------------
echo ""
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${LIL2}│${RESET} ${ORA}Zusätzliche Optionen:${RESET}                            ${LIL2}│${RESET}"
echo -e "${LIL2}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${MINT}1)${RESET} Standard, this w/ Thumbnail, Metadata and w/out Advertising)"
echo -e "  ${MINT}2)${RESET} OPTIONAL w/ Browser-Cookies from Firefox, if needed for:
    - Private/Unlisted Videos ohne Share-Link
    - Mitgliedschafts-exklusive Inhalte
    - Einige Plattformen mit Geo-Restrictions
"
echo ""
printf "${GREEN}➜${RESET} Select [1 or 2]: "
read -r OPT_CHOICE

ADDITIONAL_OPTS=""
case "$OPT_CHOICE" in
    1)
        ADDITIONAL_OPTS=""
        ;;
    2)
        echo -e "${GREEN}✓${RESET} Mit Browser-Cookies"
        ADDITIONAL_OPTS="--cookies-from-browser firefox"
        ;;
    *)
        echo -e "${YELLOW}⚠ Ungültige Auswahl, verwende Standard${RESET}"
        ;;
esac

# --- Download Execution -------------------------------------------
echo ""
echo -e "${LIL2}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${LIL2}║${RESET}  ${GREEN}Download startet...${RESET}                            ${LIL2}║${RESET}"
echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

yt-dlp \
    -f "$FORMAT" \
    --sponsorblock-remove all
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
echo -e "${LIL2}╔════════════════════════════════════════════════════╗${RESET}"
if (( STATUS != 0 )); then
    echo -e "${LIL2}║${RESET}  ${RED}✗ Fehler beim Download (exit code $STATUS)${RESET}       ${LIL2}║${RESET}"
    echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
    echo -e "${YELLOW}⚠ Prüfe:${RESET}"
    echo -e "  • URL korrekt?"
    echo -e "  • Netzwerkverbindung aktiv?"
    echo -e "  • yt-dlp aktuell? (yt-dlp -U)"
    exit $STATUS
fi

echo -e "${LIL2}║${RESET}  ${GREEN}✓ Download erfolgreich abgeschlossen!${RESET}            ${LIL2}║${RESET}"
echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${GREEN}📁 Datei gespeichert in:${RESET}"
echo -e "   ${MINT}$DL_DIR${RESET}"
echo ""


