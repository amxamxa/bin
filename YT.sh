#!/usr/bin/env bash 
# auth: amxamxa
####################################################
# YouTube Downloader for NixOS
#
# Description:
#   Compact, reliable Bash script that downloads YouTube links as mp3 (Music)
#   or mp4 (Video) using yt-dlp. Function call without arguments prompts for
#   YouTube URL and mode selection (mp3 or mp4) at startup.
#
# Requirements: yt-dlp, ffmpeg
#
# Features:
#   - Selectable download folder (defaults to $XDG_VIDEOS_DIR or $XDG_MUSIC_DIR)
#   - Automatic folder creation with permission checks
#   - Automatic, conflict-free filenames using yt-dlp template
#   - Progress bar display (built into yt-dlp)
#   - Comprehensive error handling
#   - Optional browser cookie support for restricted content
#   - SponsorBlock integration to skip advertisements
#   - Embedded thumbnails and metadata
# Usage:
#   ./YT.sh
#
################################################

# === Color Definitions =========================
# Detect true color support
if [ -n "${COLORTERM}" ] && { [ "${COLORTERM}" = "truecolor" ] || [ "${COLORTERM}" = "24bit" ]; }; then
    # Use 24-bit RGB colors (modern terminals like kitty)
    readonly PINK=$'\033[38;2;255;0;53m\033[48;2;34;0;82m'      # pink for instructions
    readonly LILA=$'\033[38;2;255;105;180m\033[48;2;75;0;130m'  # lila for choices
    readonly LIL2=$'\033[38;2;239;217;129m\033[48;2;59;14;122m'
    readonly VIO=$'\033[38;2;255;0;53m\033[48;2;34;0;82m'
    readonly BLUE=$'\033[38;2;252;222;90m\033[48;2;0;0;139m'    # BLUE for confirmation
    readonly LIME=$'\033[38;2;6;88;96m\033[48;2;0;255;255m'
    readonly RED=$'\033[38;2;240;128;128m\033[48;2;139;0;0m'    # Red for warnings

    readonly RESET=$'\033[0m'
else
    # Fallback to 256-color palette with tput
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        readonly PINK=$(tput setaf 197)$(tput setab 17)      # FG: bright red, BG: dark blue
        readonly LILA=$(tput setaf 213)$(tput setab 54)      # FG: hot pink, BG: purple
         readonly LIL2=$(tput setaf 222)$(tput setab 54)
       readonly VIO=$(tput setaf 201 )$(tput setab 54)
        # FG: wheat, BG: purple
        readonly BLUE=$(tput setaf 222)$(tput setab 18)      # FG: wheat, BG: dark blue
        readonly LIME=$(tput setaf 24)$(tput setab 51)       # FG: deep teal, BG: cyan
        readonly RED=$(tput setaf 217)$(tput setab 88)       # FG: light coral, BG: dark red
        readonly RESET=$(tput sgr0)
    else
        # No color support
        readonly PINK=""
        readonly LILA=""
        readonly LIL2=""
        readonly BLUE=""
        readonly LIME=""
        readonly RED=""
        readonly RESET=""
    fi
fi

# === ASCII Art Header ==========================
cat <<-EOF
${PINK}
  -------------------------------------
   YMM     MM                         
    VMA   ,V                           
     VMA ,V ,pW"Wq. 7MM   7MM          
      VMMP 6W     Wb MM    MM           
       MM  8M     M8 MM    MM           
       MM  YA.   ,A9 MM    MM           
     .JMML.  'Ybmd9'  'MbodYML.                 
  - - - - - - - - - - - - - - - - - - - - 
  """"""""""""                           
  l   MM             MM                  
      MM   MM   7MM  MM,dMMb.   .gP"Ya   
      MM   MM    MM  MM     Mb ,M'   Yb  
      MM   MM    MM  MM     M8 8M""""""  
      MM   MM    MM  MM.   ,M9 YM.    ,  
    .JMML.  MbodLYML.P^YbmdP'    Mbmmd' 
    -------------------------------------- ${RESET}
EOF
echo -e "${BLUE}... ... d o w n l o a d e r${RESET}"
echo -e "${LIL2}╔══════════════════════════════════════╗${RESET}"
echo -e "${LIL2}║${RESET}  ${PINK}by amxamxs${RESET} ${BLUE}sw requirements: yt-dlp, ffmpeg${RESET}              ${LIL2}║${RESET}"
echo -e "${LIL2}╚═══════════════════════════════════════╝${RESET}"
echo ""

# === URL Input ================================================================
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│${RESET} ${ORA}Enter URL:${RESET}                                       ${CYAN}│${RESET}"
# echo -e "${LIL}└─────────────────────────────────────────────────────┘${RESET}"
printf "${GREEN}➜${RESET} "
read -r URL

# Validate URL input
if [[ -z "$URL" ]]; then
    echo -e "${RED}✗ No URL provided. Aborting.${RESET}"
    exit 1
fi

# === Mode Selection ===========================================================
echo ""
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│${RESET} ${ORA}Select Mode:${RESET}                                     ${CYAN}│${RESET}"
echo -e "${LIL}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${LILA}1${RESET}) ${PINK}MP3${RESET} - Audio with 192 kbps"
echo -e "  ${LIL2}2${RESET}) ${PINK}MP4${RESET} - Video with Audio"
echo -e "  ${LILA}3${RESET}) ${RED}Exit${RESET}"
echo ""
printf "${GREEN}➜${RESET} Selection [1-3]: "
read -r MODE_CHOICE

# Process mode selection
case "$MODE_CHOICE" in
    1)
        echo -e "${GREEN}✓${RESET} ${PINK}MP3 Mode${RESET} selected"
        FORMAT="bestaudio/best"
        OUTTPL="%(title).150s.%(ext)s"
        EXTRA_OPTS="-x --audio-format mp3 --audio-quality 192k"
        DEFAULT_DIR="${XDG_MUSIC_DIR:-$HOME/Music}"
        ;;
    2)
        echo -e "${GREEN}✓${RESET} ${PINK}MP4 Mode${RESET} selected"
        FORMAT="bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        OUTTPL="%(title).150s.%(ext)s"
        EXTRA_OPTS="--merge-output-format mp4"
        DEFAULT_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}"
        ;;
    3)
        echo -e "${YELLOW}Exiting.${RESET}"
        exit 0
        ;;
    *)
        echo -e "${RED}✗ Invalid selection.${RESET}"
        exit 1
        ;;
esac

# === Download Directory =======================================================
echo ""
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${LIL2}│${RESET} ${ORA}Download Folder:${RESET}                                 ${LIL2}│${RESET}"
echo -e "${LIL2}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${BLUE}Default:${RESET} $DEFAULT_DIR"
printf "${GREEN}➜${RESET} Path (Enter = Default): "
read -r DL_DIR

# Use default directory if none specified
if [[ -z "$DL_DIR" ]]; then
    DL_DIR="$DEFAULT_DIR"
fi

# Create directory if it doesn't exist
if [[ ! -d "$DL_DIR" ]]; then
    echo -e "${PINK}⚠  Folder does not exist. Creating: $DL_DIR${RESET}"
    if ! mkdir -p "$DL_DIR"; then
        echo -e "${RED}✗ Could not create folder. Check permissions.${RESET}"
        exit 1
    fi
    echo -e "${GREEN}✓${RESET} Folder created"
fi

# === Additional Options =======================================================
echo ""
echo -e "${LIL2}┌─────────────────────────────────────────────────────┐${RESET}"
echo -e "${LIL2}│${RESET} ${ORA}Additional Options:${RESET}                              ${LIL2}│${RESET}"
echo -e "${LIL2}└─────────────────────────────────────────────────────┘${RESET}"
echo -e "  ${MINT}Enter${RESET}) Standard (with Thumbnail, Metadata, without Ads)"
echo -e "  ${MINT}c${RESET})     OPTIONAL with Browser-Cookies from Firefox"
echo -e "          (needed for private/unlisted/membership content)"
echo ""
printf "${GREEN}➜${RESET} Select [Enter or c]: "
read -r OPT_CHOICE

# Process additional options
ADDITIONAL_OPTS=""
case "$OPT_CHOICE" in
    ""|" ")
        # Default: no additional options (Enter pressed)
        echo -e "${GREEN}✓${RESET} Standard mode"
        ;;
    c|C)
        echo -e "${GREEN}✓${RESET} With Browser-Cookies"
        ADDITIONAL_OPTS="--cookies-from-browser firefox"
        ;;
    *)
        echo -e "${YELLOW}⚠  Invalid selection, using default${RESET}"
        ;;
esac

# === Download Execution =======================================================
echo ""
echo -e "${LIL2}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${LIL2}║${RESET}  ${GREEN}Download starting...${RESET}                            ${LIL2}║${RESET}"
echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

# Execute yt-dlp with all configured options
yt-dlp \
    -f "$FORMAT" \
    --sponsorblock-remove all \
    $EXTRA_OPTS \
    --embed-thumbnail \
    --embed-metadata \
    --add-metadata \
    --no-overwrites \
    --restrict-filenames \
    $ADDITIONAL_OPTS \
    --output "$DL_DIR/$OUTTPL" \
    "$URL"

# Capture exit status
STATUS=$?

# === Error Handling ===========================================================
echo ""
echo -e "${LIL2}╔════════════════════════════════════════════════════╗${RESET}"
if (( STATUS != 0 )); then
    echo -e "${LIL2}║${RESET}  ${RED}✗ Download failed (exit code $STATUS)${RESET}              ${LIL2}║${RESET}"
    echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
    echo -e "${YELLOW}⚠  Check:${RESET}"
    echo -e "  • Is the URL correct?"
    echo -e "  • Is network connection active?"
    echo -e "  • Is yt-dlp up to date? (yt-dlp -U)"
    if [[ -n "$ADDITIONAL_OPTS" ]]; then
        echo -e "  • Is Firefox profile accessible for cookies?"
    fi
    exit "$STATUS"
fi

echo -e "${LIL2}║${RESET}  ${GREEN}✓ Download completed successfully!${RESET}                ${LIL2}║${RESET}"
echo -e "${LIL2}╚════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${GREEN}📁 File saved in:${RESET}"
echo -e "   ${MINT}$DL_DIR${RESET}"
echo ""


