#!/usr/bin/env bash
# https://esahubble.org/images/archive/category/nebulae/
# ============================================================
#  Image Downloader Script
# ============================================================
#  Description:
#    Downloads all images from a given webpage into a local
#    directory. Supports common image formats and ensures
#    safe, predictable behavior.
#
#  Features:
#    - Extracts image URLs from HTML
#    - Handles relative and absolute URLs
#    - Sequential file numbering
#    - Logging of all actions
#    - Colored terminal output
#    - Basic URL validation
#
#  Security Notes:
#    - Uses safe quoting to avoid command injection
#    - Avoids deprecated or unsafe Bash constructs
#    - Does not execute untrusted HTML content
#
#  %% Script Tests:
#    Please test this script with:
#      - Valid URLs
#      - Invalid URLs
#      - Pages with no images
#      - Pages with relative image paths
#      - Slow or unreachable servers
#    This ensures robustness and reliability.
# ============================================================


# ==============================================
# CONFIGURATION
# ==============================================

OUT_DIR="./pics-down"          # Default output directory
LOG_FILE="download.log"        # Log file name

# Colors for terminal output
RESET="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
PURPLE="\e[35m"


# ==============================================
# FUNCTIONS
# ==============================================

# Display a colored message
msg() {
    echo -e "${1}${2}${RESET}"
}

# Validate URL format (must start with http:// or https://)
validate_url() {
    [[ "$1" =~ ^https?:// ]] || return 1
}

# Ensure output directory exists
init_outdir() {
    mkdir -p "$OUT_DIR"
}

# Append a message to the log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$OUT_DIR/$LOG_FILE"
}

# Convert relative URLs to absolute URLs
absolute_url() {
    local base="$1"
    local link="$2"

    # If already absolute → return as-is
    if [[ "$link" =~ ^https?:// ]]; then
        echo "$link"
    # Protocol-relative URLs (e.g. //example.com/img.jpg)
    elif [[ "$link" =~ ^// ]]; then
        echo "https:${link}"
    # Root-relative URLs (/images/pic.jpg)
    elif [[ "$link" =~ ^/ ]]; then
        echo "${base%/}${link}"
    # Relative paths (images/pic.jpg)
    else
        echo "${base%/}/$link"
    fi
}


# ==============================================
# MAIN SCRIPT LOGIC
# ==============================================

URL="$1"   # URL -Abfrage (translated: URL input)

# IF URL ist leer → ask user for URL
if [[ -z "$URL" ]]; then
    msg "$RED" "You did not provide a URL."
    echo "Please enter a URL:"
    read -r URL
fi

# IF URL not valid → ask again
if ! validate_url "$URL"; then
    msg "$RED" "You provided an incorrect URL."
    echo "Please enter a valid URL:"
    read -r URL
fi

# Initialize output directory and log file
init_outdir
log "Starting download from $URL"

msg "$BLUE" "Fetching webpage…"

# Download HTML safely
HTML=$(curl -s --fail "$URL")
if [[ -z "$HTML" ]]; then
    msg "$RED" "Error: Could not fetch webpage."
    exit 1
fi

msg "$BLUE" "Extracting image URLs…"

# Extract image URLs using regex
mapfile -t IMAGES < <(
    echo "$HTML" |
    grep -oP '(?<=src=")[^"]+\.(jpg|jpeg|png|gif|bmp|webp|svg|tiff|avif)' |
    sort -u
)

# If no images found
if (( ${#IMAGES[@]} == 0 )); then
    msg "$RED" "Warning: No images found on this page!"
    exit 0
fi

msg "$GREEN" "Found ${#IMAGES[@]} images."

# Download images sequentially
i=1
for img in "${IMAGES[@]}"; do
    ABS=$(absolute_url "$URL" "$img")
    EXT="${ABS##*.}"
    FILE=$(printf "%03d.%s" "$i" "$EXT")

    msg "$PURPLE" "Downloading: $ABS → $FILE"
    log "Downloading $ABS"

    # Safe download with overwrite protection
    wget -q --no-clobber "$ABS" -O "$OUT_DIR/$FILE"

    ((i++))
done

msg "$GREEN" "Download completed successfully!"
msg "$BLUE" "Files saved to: $OUT_DIR"
msg "$BLUE" "Detailed log saved to: $OUT_DIR/$LOG_FILE"

