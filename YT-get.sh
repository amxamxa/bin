#!/usr/bin/env zsh
*/
# todo

zsh *-> sh

Wählbarer Download-Ordner
    DEFAULT-WERT $XGD_VIDEOS
    Eingabeaufforderung
    Fehlt der Ordner → automatische Erstellung
    Fehlerschutz bei fehlenden Rechten

Automatische, konfliktfreie Dateinamen
    yt-dlp-Template:
    %(title).150s.%(ext)s
    --no-overwrites schützt vor Überschreiben
    --restrict-filenames entfernt problematische Zeichen

(x) Fortschrittsanzeige
    yt-dlp zeigt automatisch eine präzise Fortschrittsleiste
    kein weiterer Code nötig

Fehlerhandling
    Prüfung von $?
    klare Fehlermeldung
    Exit-Code wird korrekt durchgereicht
----------------------------------------------------------------
*/

# kompaktes, zuverlässiges Zsh-Skript für NixOS, das YouTube-Links per yt-dlp herunterlädt und dich beim Start nach URL und Modus fragt.
SKY="\033[38;2;62;36;129m\033[48;2;135;206;235m"
MINT="\033[38;2;6;88;96m\033[48;2;144;238;144m"
NIGHT="\033[38;2;252;222;90m\033[48;2;0;0;139m"
RED="\033[38;2;240;128;128m\033[48;2;139;0;0m"
RASPBERRY="\033[38;2;32;0;21m\033[48;2;221;160;221m"
PINK="\033[38;2;32;0;21m\033[48;2;163;64;217m"
VIOLETT="\033[38;2;255;0;53m\033[48;2;34;0;82m"
ORA="\033[38;2;0;17;204m\033[48;2;255;140;0m";
RESET="\033[0m"

printf "%s" "$VIOLETT"
cat <<'EOF'
  `YMM'   `MM'                 
    VMA   ,V                   
     VMA ,V ,pW"Wq.`7MM  `7MM  
      VMMP 6W'   `Wb MM    MM  
       MM  8M     M8 MM    MM  
       MM  YA.   ,A9 MM    MM  
     .JMML. `Ybmd9'  `Mbod"YML.                                      
                
 MMP""MM""YMM       *MM                 
 P'   MM   `7        MM                 
      MM `7MM  `7MM  MM,dMMb.   .gP"Ya  
      MM   MM    MM  MM    `Mb ,M'   Yb 
      MM   MM    MM  MM     M8 8M=`=`=`= 
      MM   MM    MM  MM.   ,M9 YM.    , 
    .JMML. `Mbod"YML.P^YbmdP'   `Mbmmd'                                   

EOF
printf "%s" "$RESET"

printf "%s" "$NIGHT"
cat <<'EOF'

     8888b.   dP"Yb  Yb        dP 88b 88 
     8I  Yb dP   Yb  Yb  db  dP  88Yb88 
     8I  dY Yb   dP   YbdPYbdP   88 Y88 
     8888Y"   YbodP     YP  YP    88  Y8 
88      dP"Yb     db    8888b.  888888 88""Yb 
88     dP   Yb   dPYb    8I  Yb 88__   88__dP 
88  .o Yb   dP  dP__Yb   8I  dY 88""   88"Yb  
88ood8  YbodP  dP""""Yb 8888Y"  888888 88  Yb 

EOF
printf "%s" "$RESET"
echo -e "${VIOLETT} \t amxamxs \v aka \v YouTube Downloader"

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

