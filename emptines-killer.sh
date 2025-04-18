#!/usr/bin/env bash
# ==============================================
# SPACE-TO-DASH CONVERTER
# A script to replace spaces with dashes in filenames and directories.
# Features:
# - Dry-run mode (preview changes)
# - Interactive confirmation
# - Configurable directory depth for grouping
# - Colored terminal output
# - Safe handling of special characters
# ==============================================

# ----------------------------
# COLOR DEFINITIONS (ANSI ESCAPE CODES)
# ----------------------------
RESET="\e[0m"               	   	   # Reset all formatting
COLOR_DRY_RUN="\033[38;2;255;200;0m"   # Yellow for dry-run
COLOR_SUCCESS="\033[38;2;0;255;0m"     # Green for success
COLOR_ERROR="\033[38;2;255;50;50m"     # Red for errors
COLOR_PROMPT="\033[38;2;100;149;237m"  # Blue for prompts
COLOR_INFO="\033[38;2;200;200;200m"    # Gray for info

# ----------------------------
# CONFIGURABLE SETTINGS (DEFAULTS)
# ----------------------------
GROUP_FROM_DEPTH=3             # Group output from this directory depth onward
SHOW_FULL_PATHS=false          # Show full paths instead of relative ones
DRY_RUN_ONLY=false             # Only show dry-run, skip confirmation prompt

# ----------------------------
# FUNCTION: Print a formatted message
# Usage: _print_msg [TYPE] "Message"
# ----------------------------
_print_msg() {
    local type="$1"
    local msg="$2"
    local color=""

    case "$type" in
        "dryrun") color="${COLOR_DRY_RUN}" ;;
        "success") color="${COLOR_SUCCESS}" ;;
        "error") color="${COLOR_ERROR}" ;;
        "prompt") color="${COLOR_PROMPT}" ;;
        *) color="${COLOR_INFO}" ;;
    esac

    echo -e "${color}${msg}${RESET}"
}

# ----------------------------
# FUNCTION: Preview changes (dry-run)
# ----------------------------
_preview_changes() {
    _print_msg "info" "\n=== DRY-RUN MODE (Preview Changes) ==="
    local counter=0

    find . -name "* *" -print | while read -r filepath; do
        ((counter++))
        
        # Generate new filename (spaces → dashes)
        local new_filepath=$(echo "$filepath" | tr ' ' '-')
        
        # Apply path grouping if enabled
        if [ "$SHOW_FULL_PATHS" = false ]; then
            local display_path=$(echo "$filepath" | cut -d'/' -f"${GROUP_FROM_DEPTH}"-)
            local display_new_path=$(echo "$new_filepath" | cut -d'/' -f"${GROUP_FROM_DEPTH}"-)
        else
            local display_path="$filepath"
            local display_new_path="$new_filepath"
        fi

        _print_msg "dryrun" "[${counter}] ${display_path} → ${display_new_path}"
    done

    _print_msg "info" "Total files/dirs to be renamed: ${counter}"
}

# ----------------------------
# FUNCTION: Execute renaming
# ----------------------------
_execute_renaming() {
    _print_msg "info" "\n=== STARTING RENAMING (Spaces → Dashes) ==="
    local success_count=0
    local error_count=0

    find . -name "* *" -print0 | while IFS= read -r -d '' filepath; do
        local new_filepath=$(echo "$filepath" | tr ' ' '-')
        
        if mv -v "$filepath" "$new_filepath" 2>/dev/null; then
            ((success_count++))
        else
            ((error_count++))
            _print_msg "error" "Failed to rename: ${filepath}"
        fi
    done

    _print_msg "success" "\n=== RENAMING COMPLETE ==="
    _print_msg "info" "Successfully renamed: ${success_count}"
    [ "$error_count" -gt 0 ] && _print_msg "error" "Failed attempts: ${error_count}"
}

# ----------------------------
# FUNCTION: Parse command-line arguments
# ----------------------------
_parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --full-paths)
                SHOW_FULL_PATHS=true
                shift
                ;;
            --depth=*)
                GROUP_FROM_DEPTH="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN_ONLY=true
                shift
                ;;
            *)
                _print_msg "error" "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# ----------------------------
# MAIN EXECUTION
# ----------------------------
main() {
    _parse_arguments "$@"

    _preview_changes

    if [ "$DRY_RUN_ONLY" = false ]; then
        _print_msg "prompt" "\nProceed with renaming? (y/N) "
        read -r -n 1 response
        echo  # Move to new line
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            _execute_renaming
        else
            _print_msg "info" "Operation cancelled by user."
        fi
    fi
}

main "$@"
