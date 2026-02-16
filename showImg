#!/usr/bin/env bash
########################################################
# File: showimg
# ------------------------------------------------------
# Universal terminal image viewer.
# Works in all terminals, including:
#  - Kitty (graphics protocol)
#  - WezTerm (imgcat)
#  - Konsole (konsole-graphics)
#  - tmux, screen, SSH, TTY
#  - Any POSIX terminal via chafa
# ------------------------------------------------------
# Features
# * Auto-detects best display method
# * Auto-zoom to terminal height
# * Auto-fit to terminal width
# * Multi-image side-by-side mode
# * Safe to source; no shell opts changed
# * No dependencies required except:
#     - kitty (optional)
#     - wezterm (optional)
#     - konsole-graphics (optional)
#     - chafa (recommended fallback)
# ------------------------------------------------------
# Usage
#   showimg <image>
#   showimg img1 img2 img3
# Examples:
#   showimg ~/pic.png
#   showimg a.png b.png c.png
# ------------------------------------------------------
# Behavior
# * If multiple images are given:
#     → chafa renders them side-by-side
# * If one image is given:
#     → Kitty graphics if available
#     → else WezTerm imgcat
#     → else Konsole graphics
#     → else chafa fallback
# * Auto-scaling:
#     → Terminal width via tput cols
#     → Terminal height via tput lines
# ------------------------------------------------------
# Notes
# * Kitty graphics do not work inside tmux
# * chafa works everywhere, even SSH/TTY
# * No external state is modified
# * Script is safe to source
########################################################

#-------------------------------------------------------
# Get terminal width in columns
#-------------------------------------------------------
get_term_width() {
    tput cols 2>/dev/null || echo 80
}

#-------------------------------------------------------
# Get terminal height in rows
#-------------------------------------------------------
get_term_height() {
    tput lines 2>/dev/null || echo 24
}

#-------------------------------------------------------
# Display image using Kitty graphics
#-------------------------------------------------------
show_kitty() {
    local file="$1"
    local width="$2"
    local height="$3"

    kitty +kitten icat \
        --place "${width}x${height}@0x0" \
        "$file"
}

#-------------------------------------------------------
# Display image using WezTerm imgcat
#-------------------------------------------------------
show_wezterm() {
    local file="$1"
    wezterm imgcat "$file"
}

#-------------------------------------------------------
# Display image using Konsole graphics
#-------------------------------------------------------
show_konsole() {
    local file="$1"
    konsole-graphics display "$file"
}

#-------------------------------------------------------
# Display image using chafa (ASCII fallback)
#-------------------------------------------------------
show_chafa() {
    local file="$1"
    local width="$2"
    local height="$3"

    chafa --size "${width}x${height}" "$file"
}

#-------------------------------------------------------
# Display multiple images side-by-side
#-------------------------------------------------------
show_side_by_side() {
    local width height
    width=$(get_term_width)
    height=$(get_term_height)

    # Use chafa for multi-image mode
    chafa --size "${width}x${height}" "$@"
}

#-------------------------------------------------------
# Main dispatcher with auto-detection
#-------------------------------------------------------
showimg_main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: showimg <img1> [img2...]"
        return 1
    fi

    local width height
    width=$(get_term_width)
    height=$(get_term_height)

    # Multi-image mode
    if [[ $# -gt 1 ]]; then
        show_side_by_side "$@"
        return 0
    fi

    local file="$1"

    # Kitty graphics
    if [[ -n "$KITTY_WINDOW_ID" ]] \
       && command -v kitty >/dev/null; then
        show_kitty "$file" "$width" "$height"
        return 0
    fi

    # WezTerm
    if command -v wezterm >/dev/null; then
        show_wezterm "$file"
        return 0
    fi

    # Konsole
    if [[ "$TERM" == konsole* ]] \
       && command -v konsole-graphics >/dev/null; then
        show_konsole "$file"
        return 0
    fi

    # Fallback: chafa
    if command -v chafa >/dev/null; then
        show_chafa "$file" "$width" "$height"
        return 0
    fi

    echo "No supported image method found."
    return 1
}

#-------------------------------------------------------
# Execute main only when not sourced
#-------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    showimg_main "$@"
fi
