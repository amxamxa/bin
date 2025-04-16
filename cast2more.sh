#!/usr/bin/env bash
##########################################
## ╔═╗╦╦  ╔═╗ ############################
## ╠╣ ║║  ║╣ 
## ╚  ╩╩═╝╚═╝
##  -NAME:	   cast2more.sh
##  -VERSION/tag: 0.1
## - Github:      github.com/amxamxa/bin
## - DATE:        2025-Feb-09                
## ---------------------------------------
## To do/ Known Bugs /or depends:
##     Requires 'agg' (asciinema-agg) and 'ffmpeg' commands
## ---------------------------------------
## Cast2More - Convert asciinema casts to GIFs and MP4s
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## This script allows you to convert asciinema cast (.cast) files into GIF and MP4 video formats.
## It provides options to generate only GIF, only MP4, or both, as well as control the output filenames.
## ./cast2more.sh -i project@2025-04-11.cast --only-gif
##
## Main functions/workflow:
## • Parses command-line arguments to get input .cast file and output options
## • Checks for required dependencies ('agg' and 'ffmpeg')
## • Generates GIF from input .cast file
## • Converts GIF to MP4 video format
## • Optionally removes the intermediate GIF file
#####################################

#===========================#
#  COLOR DEFINITIONS       #
#===========================#
RESET="\e[0m"
VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"
GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"
RED="\033[38;2;240;138;100m\033[48;2;147;18;61m"
BLUE="\033[38;2;100;149;237m"
PURPLE="\033[38;2;85;85;255m\033[48;2;21;16;46m"

#===========================#
#  FUNCTION DEFINITIONS     #
#===========================#
show_help() {
    echo -e "${PURPLE}Usage:${RESET} $0 [-i input.cast] [-o output_name] [--only-gif] [--only-mp4] [--keep-gif]"
    echo -e "\nOptions:"
    echo -e "  -i, --input        Input .cast file (required)"
    echo -e "  -o, --output       Output base name (optional, default is input basename)"
    echo -e "  --only-gif         Only generate .gif, skip .mp4"
    echo -e "  --only-mp4         Only generate .mp4, assumes .gif already exists"
    echo -e "  -h, --help         Show this help message"
}

#===========================#
#  PARSE ARGUMENTS          #
#===========================#
INPUT_FILE=""
OUTPUT_NAME=""
ONLY_GIF=false
ONLY_MP4=false
KEEP_GIF=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        --only-gif)
            ONLY_GIF=true
            shift
            ;;
        --only-mp4)
            ONLY_MP4=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: Input file is required${RESET}"
    show_help
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: File not found: $INPUT_FILE${RESET}"
    exit 1
fi

if [[ -z "$OUTPUT_NAME" ]]; then
    OUTPUT_NAME="${INPUT_FILE%%.*}"
fi

#===========================#
#  CHECK DEPENDENCIES       #
#===========================#
command -v agg >/dev/null 2>&1 || {
    echo -e "${RED}Error: 'agg' command not found. Please install asciinema-agg.${RESET}"
    exit 1
}

command -v ffmpeg >/dev/null 2>&1 || {
    echo -e "${RED}Error: 'ffmpeg' command not found. Please install ffmpeg.${RESET}"
    exit 1
}

#===========================#
#  GENERATE GIF              #
#===========================#
GIF_FILE="$OUTPUT_NAME.gif"
MP4_FILE="$OUTPUT_NAME.mp4"

if [[ "$ONLY_MP4" = false ]]; then
    echo -e "${BLUE}Generating GIF from $INPUT_FILE...${RESET}"
    agg "$INPUT_FILE" "$GIF_FILE"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to generate GIF.${RESET}"
        exit 1
    fi
    echo -e "${GREEN}GIF saved as $GIF_FILE${RESET}"
fi

#===========================#
#  CONVERT TO MP4           #
#===========================#
if [[ "$ONLY_GIF" = false ]]; then
    echo -e "${BLUE}Converting $GIF_FILE to MP4...${RESET}"
    ffmpeg -i "$GIF_FILE" -movflags faststart -pix_fmt yuv420p \
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$MP4_FILE"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to convert to MP4.${RESET}"
        exit 1
    fi
    echo -e "${GREEN}MP4 saved as $MP4_FILE${RESET}"

    if [[ "$KEEP_GIF" = false ]]; then
        echo -e "${BLUE}Removing intermediate GIF...${RESET}"
        rm "$GIF_FILE"
    fi
fi

#===========================#
#  DONE                     #
#===========================#
echo -e "${GREEN}Done!${RESET}"
exit 0
