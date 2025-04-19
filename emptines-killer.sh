#!/usr/bin/env bash
################################################################################
#   ________author:______amxamxa___________________
#    _ _ _filename:______emptines-killer.sh_______________________
#
#            Space to Dash Filename Converter
#           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# This script recursively processes directories and files, replacing spaces
# in names with dashes (default) or removing spaces entirely (with -s option).
#
# Features:
# - Interactive group processing with preview
# - Color-coded output and prompts
# - Dry-run mode and safe handling
# - Configurable batch processing
#
# Usage:
#   ./emptines-killer.sh [options] [directory]
#
# Options:
#   -s, --no-space    Remove spaces instead of replacing with dashes
#   -d N, --depth N   Set directory grouping depth (default: 2)
#   -b N, --batch N   Set max files per prompt (default: 20)
#   -n, --dry-run     Show changes without executing
#   -h, --help        Show this help message
#
# Safety:
# - Always shows preview before making changes
# - Handles special characters in filenames
# - Asks for confirmation before each group
################################################################################

# ANSI color codes for terminal output formatting
RESET="\e[0m"
COLOR_DRY_RUN="\033[38;2;255;200;0m"  # Yellow
COLOR_SUCCESS="\033[38;2;0;255;0m"    # Green
COLOR_ERROR="\033[38;2;255;50;50m"    # Red
COLOR_PROMPT="\033[38;2;6;88;96m\033[48;2;0;255;255m" # Cyan
COLOR_GROUP="\033[38;2;85;85;255m"    # Purple
COLOR_PATH="\033[38;2;170;170;255m"   # Light blue

# Default configuration
REPLACE_CHAR="-"           # Default replacement character
GROUP_DEPTH=2              # How many directory levels to group by
BATCH_SIZE=20              # Max files to show per prompt
DRY_RUN=false              # Dry-run mode flag
TARGET_DIR="."             # Default target directory
PROCESS_ALL=false          # Flag for "all" option

# Print formatted messages with color-coded labels
_print_msg() {
    local type="$1"
    local msg="$2"
    local color=""
    case "$type" in
        "dryrun") color="$COLOR_DRY_RUN" ;;
        "success") color="$COLOR_SUCCESS" ;;
        "error") color="$COLOR_ERROR" ;;
        "prompt") color="$COLOR_PROMPT" ;;
        "group") color="$COLOR_GROUP" ;;
        *) color="$RESET" ;;
    esac
    echo -e "${color}${msg}${RESET}"
}

# Display help information
show_help() {
    echo "Usage: $0 [options] [directory]"
    echo
    echo "Recursively replace spaces in filenames and directories with dashes"
    echo "or remove spaces entirely (with -s option)."
    echo
    echo "Options:"
    echo "  -s, --no-space    Remove spaces instead of replacing with dashes"
    echo "  -d N, --depth N   Set directory grouping depth (default: 2)"
    echo "  -b N, --batch N   Set max files per prompt (default: 20)"
    echo "  -n, --dry-run     Show changes without executing"
    echo "  -h, --help        Show this help message"
    echo
    echo "Interactive controls:"
    echo "  y - Process this group"
    echo "  n - Skip this group"
    echo "  a - Process all remaining without asking"
    echo "  q - Quit the script"
    exit 0
}

# Validate and parse command line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -s|--no-space) REPLACE_CHAR="" ;;
            -d|--depth)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    GROUP_DEPTH="$2"
                    shift
                else
                    _print_msg "error" "Invalid depth value: $2"
                    exit 1
                fi
                ;;
            -b|--batch)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    BATCH_SIZE="$2"
                    shift
                else
                    _print_msg "error" "Invalid batch size: $2"
                    exit 1
                fi
                ;;
            -n|--dry-run) DRY_RUN=true ;;
            -h|--help) show_help ;;
            *)
                if [[ -d "$1" ]]; then
                    TARGET_DIR="$1"
                else
                    _print_msg "error" "Invalid directory: $1"
                    exit 1
                fi
                ;;
        esac
        shift
    done
}

# Generate the new name by replacing spaces
generate_new_name() {
    local old_name="$1"
    if [[ -z "$REPLACE_CHAR" ]]; then
        # Remove spaces entirely
        echo "${old_name// /}"
    else
        # Replace spaces with dashes (or specified character)
        echo "${old_name// /$REPLACE_CHAR}"
    fi
}

# Find all files and directories with spaces, group them by common parents
find_and_group_items() {
    local target_dir="$1"
    # Find all items with spaces, excluding . and .. directories
    find "$target_dir" -name "* *" -not -path "." -not -path ".." -print0 | 
    while IFS= read -r -d '' item; do
        # Get the parent directory path
        parent_dir=$(dirname "$item")
        # Create a grouping key based on the specified depth
        group_key=$(echo "$parent_dir" | awk -F'/' -v depth="$GROUP_DEPTH" '{
            for (i=1; i<=depth && i<=NF; i++) {
                printf "%s/", $i
            }
        }')
        echo "$group_key|$item"
    done | sort | awk -F'|' '
        # Group items by their common parent key
        {
            if ($1 != last_group) {
                if (items_in_group > 0) print "---GROUP_END---"
                print "---GROUP_START---"
                print $1
                last_group = $1
                items_in_group = 0
            }
            print $2
            items_in_group++
        }
        END {
            if (items_in_group > 0) print "---GROUP_END---"
        }'
}

# Preview changes for a group of items
preview_changes() {
    local group_path="$1"
    shift
    local items=("$@")
    
    _print_msg "group" "\nGroup: $group_path"
    _print_msg "group" "----------------------------------------"
    
    for item in "${items[@]}"; do
        local new_name=$(generate_new_name "$item")
        if [[ "$item" != "$new_name" ]]; then
            echo -e "${COLOR_PATH}Old: $item${RESET}"
            echo -e "${COLOR_SUCCESS}New: $new_name${RESET}"
            echo
        fi
    done
}

# Process a group of items (rename files/directories)
process_group() {
    local group_path="$1"
    shift
    local items=("$@")
    local success_count=0
    local skip_count=0
    local error_count=0

    for item in "${items[@]}"; do
        local new_name=$(generate_new_name "$item")
        
        if [[ "$item" != "$new_name" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                if mv -v -- "$item" "$new_name" 2>/dev/null; then
                    ((success_count++))
                else
                    _print_msg "error" "Failed to rename: $item"
                    ((error_count++))
                fi
            else
                ((success_count++))
            fi
        else
            ((skip_count++))
        fi
    done

    if [[ "$DRY_RUN" == false ]]; then
        _print_msg "success" "Processed group: $success_count renamed, $skip_count unchanged, $error_count errors"
    else
        _print_msg "dryrun" "Dry run complete for group: $success_count would be renamed, $skip_count unchanged"
    fi
}

# Prompt user for confirmation with multiple options
confirm_action() {
    local group_path="$1"
    local item_count="$2"
    
    while true; do
        _print_msg "prompt" "\nProcess this group? [y/n/a/q] (y=yes, n=no, a=all, q=quit)"
        _print_msg "prompt" "Group: $group_path ($item_count items)"
        read -r -n 1 response
        echo
        
        case "$response" in
            [yY]) return 0 ;;   # Yes, process this group
            [nN]) return 1 ;;   # No, skip this group
            [aA])              # All, process all remaining
                PROCESS_ALL=true
                return 0
                ;;
            [qQ])             # Quit the script
                _print_msg "error" "Operation cancelled by user."
                exit 0
                ;;
            *)
                _print_msg "error" "Invalid option. Please choose y, n, a, or q."
                ;;
        esac
    done
}

# Main processing function
main() {
    parse_arguments "$@"
    
    _print_msg "dryrun" "Starting processing with options:"
    _print_msg "dryrun" "  Target directory: $TARGET_DIR"
    _print_msg "dryrun" "  Replacement: ${REPLACE_CHAR:-<remove spaces>}"
    _print_msg "dryrun" "  Group depth: $GROUP_DEPTH"
    _print_msg "dryrun" "  Batch size: $BATCH_SIZE"
    _print_msg "dryrun" "  Dry run: $DRY_RUN"
    echo

    # Find and group items with spaces in their names
    while IFS= read -r line; do
        if [[ "$line" == "---GROUP_START---" ]]; then
            # Start of a new group
            read -r group_path
            items=()
        elif [[ "$line" == "---GROUP_END---" ]]; then
            # End of current group - process it
            if [[ "${#items[@]}" -gt 0 ]]; then
                preview_changes "$group_path" "${items[@]}"
                
                if [[ "$PROCESS_ALL" == false ]]; then
                    confirm_action "$group_path" "${#items[@]}"
                    [[ "$?" -eq 1 ]] && continue
                fi
                
                process_group "$group_path" "${items[@]}"
            fi
        else
            # Add item to current group (if within batch size)
            if [[ "${#items[@]}" -lt "$BATCH_SIZE" ]]; then
                items+=("$line")
            fi
        fi
    done < <(find_and_group_items "$TARGET_DIR")

    _print_msg "success" "\nProcessing complete!"
    if [[ "$DRY_RUN" == true ]]; then
        _print_msg "dryrun" "This was a dry run - no files were actually modified."
    fi
}

# Execute main function with all arguments
main "$@"
