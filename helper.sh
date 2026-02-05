#!/usr/bin/env bash
##########################################
## ╔═╗╦╦  ╔═╗ ############################
## ╠╣ ║║  ║╣  ############################
## ╚  ╩╩═╝╚═╝ ############################
##  -NAME:        how.sh
##  -VERSION/tag: 0.4.1
##  -AUTHOR:      max kempter
##  -Github:      github.com/amxamxa/was.sh
##  -DATE:        2025-Feb-20                
## ---------------------------------------
## Command Documentation Explorer
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## This script collects information about commands using multiple sources
## (tldr, cheat, cheat.sh, man) with advanced formatting options.
##
## NEW FEATURES in v0.4.1:
##   • Fixed: Regex security check syntax error
##   • Fixed: Source array splitting issue
##   • Fixed: --list exit code problem
##   • Fixed: Multi-source search with proper filtering
##
## MAIN FUNCTIONS:
##   • Checks for available documentation sources dynamically
##   • Displays help and version information
##   • Retrieves documentation for a specified command
##   • Supports interactive selection of available sources
##   • Sequential multi-source display with --all flag
##   • Displays the last executed command if no arguments provided
## ---------------------------------------
## To do/Known Bugs/Dependencies:
##   • Sources checked dynamically - no hard dependencies
##   • Optional: bat for enhanced man page viewing
##   • For NixOS: Use nix-shell or nix profile to install tools
## ---------------------------------------
##########################################

# Strict mode for better error handling and security
set -euo pipefail

# Color definitions for terminal output
COL_USER="\033[38;5;4m\033[48;5;183m"       # Blue text on light purple
COL_ACCENT="\033[38;5;0m\033[48;5;164m"     # Black text on purple
COL_RES="\033[38;5;220m\033[48;5;18m"       # Yellow text on dark blue
COL_SUCCESS="\033[38;5;46m\033[48;5;22m"    # Green text on dark green
COL_ERROR="\033[38;5;210m\033[48;5;88m"     # Light coral text on dark red
COL_WARNING="\033[38;5;214m\033[48;5;94m"   # Orange text on brown
COL_INFO="\033[38;5;159m\033[48;5;23m"      # Light cyan text on dark cyan
COL_SOURCE="\033[38;5;51m\033[48;5;17m"     # Bright cyan text on dark blue
COL_SEP="\033[38;5;240m\033[48;5;233m"      # Gray text on dark gray
RESET="\033[0m"                             # Reset all attributes

# Display help information
function show_help() {
    echo -e "\n${COL_ACCENT}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${COL_ACCENT}  how.sh - Command Documentation Explorer  ${RESET}"
    echo -e "${COL_ACCENT}╚══════════════════════════════════════════╝${RESET}\n"
    echo -e "${COL_USER}Usage:${RESET} ${COL_RES}./how.sh [OPTIONS] [COMMAND]${RESET}\n"
    echo -e "${COL_USER}Options:${RESET}"
    echo -e "  ${COL_ACCENT}-h, --help${RESET}        Show this help message"
    echo -e "  ${COL_ACCENT}-v, --version${RESET}     Show version information"
    echo -e "  ${COL_ACCENT}-s, --source${RESET}      Specify source directly (tldr|cheat|man|cheat.sh|all)"
    echo -e "  ${COL_ACCENT}-a, --all${RESET}         Show ALL available sources sequentially"
    echo -e "  ${COL_ACCENT}-l, --list${RESET}        List all available sources\n"
    echo -e "${COL_USER}Examples:${RESET}"
    echo -e "  ${COL_RES}./how.sh curl${RESET}              # Interactive info about curl"
    echo -e "  ${COL_RES}./how.sh -s man ls${RESET}        # Show man page for ls"
    echo -e "  ${COL_RES}./how.sh -a tar${RESET}           # Show ALL available sources for tar"
    echo -e "  ${COL_RES}./how.sh --list${RESET}           # List installed documentation tools"
    echo -e "  ${COL_RES}./how.sh --help${RESET}           # Display this help"
    echo -e "  ${COL_RES}./how.sh${RESET}                  # Show last executed command\n"
    echo -e "${COL_USER}Available sources (if installed):${RESET}"
    echo -e "  ${COL_ACCENT}tldr${RESET}    - Simplified, practical examples"
    echo -e "  ${COL_ACCENT}cheat${RESET}   - Local cheat sheets"
    echo -e "  ${COL_ACCENT}cheat.sh${RESET} - Community cheat sheets from the web (requires curl)"
    echo -e "  ${COL_ACCENT}man${RESET}     - Traditional manual pages"
}

# Display version information
function show_version() {
    echo -e "\n${COL_ACCENT}how.sh${RESET} | Version 0.4.1 | (c) 2025 Max Kempter"
    echo -e "${COL_USER}Features:${RESET} Dynamic source detection • Multi-source search • NixOS compatible"
}

# Check and list available sources
function list_sources() {
    echo -e "\n${COL_ACCENT}Checking available documentation sources...${RESET}\n"
    
    local available_count=0
    
    echo -e "${COL_USER}Installed documentation tools:${RESET}"
    
    # Check tldr
    if command -v tldr &>/dev/null; then
        echo -e "  ${COL_SUCCESS}✓ tldr${RESET} - $(tldr --version 2>/dev/null | head -1 || echo 'Installed')"
        ((available_count++))
    else
        echo -e "  ${COL_ERROR}✗ tldr${RESET} - Not installed"
    fi
    
    # Check cheat
    if command -v cheat &>/dev/null; then
        echo -e "  ${COL_SUCCESS}✓ cheat${RESET} - $(cheat --version 2>/dev/null | head -1 || echo 'Installed')"
        ((available_count++))
    else
        echo -e "  ${COL_ERROR}✗ cheat${RESET} - Not installed"
    fi
    
    # Check man (almost always available)
    if command -v man &>/dev/null; then
        echo -e "  ${COL_SUCCESS}✓ man${RESET} - $(man --version 2>/dev/null | head -1 || echo 'Installed')"
        ((available_count++))
    else
        echo -e "  ${COL_ERROR}✗ man${RESET} - Not installed (unusual!)"
    fi
    
    # Check curl for cheat.sh
    if command -v curl &>/dev/null; then
        echo -e "  ${COL_SUCCESS}✓ cheat.sh${RESET} - Available via curl"
        ((available_count++))
    else
        echo -e "  ${COL_ERROR}✗ cheat.sh${RESET} - curl not installed"
    fi
    
    # Check bat (optional)
    if command -v bat &>/dev/null; then
        echo -e "  ${COL_INFO}● bat${RESET} - Available for enhanced man pages"
    fi
    
    echo -e "\n${COL_INFO}Total available sources: ${available_count}${RESET}"
    
    # NixOS specific advice
    if [[ -f /etc/os-release ]] && grep -qi "nixos" /etc/os-release; then
        echo -e "\n${COL_WARNING}NixOS detected:${RESET}"
        echo -e "Install missing tools with: ${COL_RES}nix shell nixpkgs#<tool>${RESET}"
        echo -e "Example: ${COL_RES}nix shell nixpkgs#tldr nixpkgs#cheat${RESET}"
    fi
    
    return 0
}

# Get list of available sources as an array
function get_available_sources() {
    local sources=()
    
    # Check and add available sources
    if command -v cheat &>/dev/null; then
        sources+=("cheat (fuzzy)")
        sources+=("cheat (regex)")
    fi
    
    if command -v tldr &>/dev/null; then
        sources+=("tldr")
    fi
    
    if command -v curl &>/dev/null; then
        sources+=("cheat.sh")
    fi
    
    if command -v man &>/dev/null; then
        sources+=("man")
    fi
    
    # Always add "all sources" if we have at least 2 sources
    if [[ ${#sources[@]} -ge 2 ]]; then
        sources+=("ALL SOURCES (sequential)")
    fi
    
    # Return the array properly
    printf '%s\n' "${sources[@]}"
}

# Show the last executed command safely
function last_command() {
    if [[ $- == *i* ]] && set -o | grep -q 'history.*on'; then
        local last_cmd
        if last_cmd=$(HISTTIMEFORMAT="" history 1 | sed 's/^ *[0-9]* *//' 2>/dev/null); then
            echo -e "\n${COL_ACCENT}↪ Last command:${RESET} ${COL_RES}${last_cmd}${RESET}\n"
        else
            echo -e "\n${COL_WARNING}No command history available.${RESET}"
            show_help
        fi
    else
        echo -e "\n${COL_WARNING}Running in non-interactive shell. No history available.${RESET}"
        show_help
    fi
}

# Fetch from a single source
function fetch_from_source() {
    local src="$1"
    local cmd="$2"
    
    case "$src" in
        "cheat (fuzzy)")
            echo -e "\n${COL_SEP}────────────────────────────────────────────${RESET}"
            echo -e "${COL_SOURCE}SOURCE: cheat (fuzzy search)${RESET}"
            echo -e "${COL_SEP}────────────────────────────────────────────${RESET}\n"
            cheat -s "$cmd" 2>/dev/null || echo -e "${COL_WARNING}No cheat entry found${RESET}"
            ;;
        "cheat (regex)")
            echo -e "\n${COL_SEP}────────────────────────────────────────────${RESET}"
            echo -e "${COL_SOURCE}SOURCE: cheat (regex search)${RESET}"
            echo -e "${COL_SEP}────────────────────────────────────────────${RESET}\n"
            cheat -r "$cmd" 2>/dev/null || echo -e "${COL_WARNING}No cheat entry found${RESET}"
            ;;
        "tldr")
            echo -e "\n${COL_SEP}────────────────────────────────────────────${RESET}"
            echo -e "${COL_SOURCE}SOURCE: tldr${RESET}"
            echo -e "${COL_SEP}────────────────────────────────────────────${RESET}\n"
            tldr --color always "$cmd" 2>/dev/null || echo -e "${COL_WARNING}No tldr entry found${RESET}"
            ;;
        "cheat.sh")
            echo -e "\n${COL_SEP}────────────────────────────────────────────${RESET}"
            echo -e "${COL_SOURCE}SOURCE: cheat.sh (web)${RESET}"
            echo -e "${COL_SEP}────────────────────────────────────────────${RESET}\n"
            curl --silent --max-time 5 "https://cheat.sh/$cmd" 2>/dev/null || \
                echo -e "${COL_WARNING}Could not fetch from cheat.sh (network error)${RESET}"
            ;;
        "man")
            echo -e "\n${COL_SEP}────────────────────────────────────────────${RESET}"
            echo -e "${COL_SOURCE}SOURCE: man page${RESET}"
            echo -e "${COL_SEP}────────────────────────────────────────────${RESET}\n"
            if command -v bat &>/dev/null; then
                man "$cmd" 2>/dev/null | bat --language=man --style=plain --color=always --paging=never 2>/dev/null || \
                    echo -e "${COL_WARNING}No man entry found${RESET}"
            else
                MANPAGER="cat" man "$cmd" 2>/dev/null | head -100 2>/dev/null || \
                    echo -e "${COL_WARNING}No man entry found (showing first 100 lines)${RESET}"
            fi
            ;;
        *)
            echo -e "${COL_ERROR}Unknown source: $src${RESET}"
            ;;
    esac
}

# Sequential multi-source search
function search_all_sources() {
    local cmd="$1"
    
    # Get available sources
    local available_sources=()
    while IFS= read -r line; do
        available_sources+=("$line")
    done < <(get_available_sources)
    
    # Filter out "ALL SOURCES" option
    local sources_to_search=()
    for src in "${available_sources[@]}"; do
        if [[ "$src" != "ALL SOURCES (sequential)" ]]; then
            sources_to_search+=("$src")
        fi
    done
    
    if [[ ${#sources_to_search[@]} -eq 0 ]]; then
        echo -e "\n${COL_ERROR}ERROR:${RESET} No documentation sources available!"
        list_sources
        return 1
    fi
    
    echo -e "\n${COL_ACCENT}══════════════════════════════════════════════${RESET}"
    echo -e "${COL_ACCENT}Showing ALL available sources for:${RESET} ${COL_RES}$cmd${RESET}"
    echo -e "${COL_ACCENT}══════════════════════════════════════════════${RESET}"
    echo -e "${COL_INFO}Found ${#sources_to_search[@]} source(s)${RESET}\n"
    
    # Create a temporary file for combined output
    local temp_file
    temp_file=$(mktemp)
    
    # Fetch from each source and append to temp file
    for src in "${sources_to_search[@]}"; do
        echo "Processing: $src" >&2
        fetch_from_source "$src" "$cmd" >> "$temp_file" 2>&1
        echo "" >> "$temp_file"  # Add spacing between sources
    done
    
    # Display with pager
    if command -v less &>/dev/null; then
        less -R "$temp_file"
    else
        cat "$temp_file"
    fi
    
    # Cleanup
    rm -f "$temp_file"
    echo -e "\n${COL_SUCCESS}✓ Multi-source search completed${RESET}"
}

# Interactive command documentation fetch
function get_command_info() {
    local cmd="$1"
    local source_selected="$2"
    
    # Get available sources
    local available_sources=()
    while IFS= read -r line; do
        available_sources+=("$line")
    done < <(get_available_sources)
    
    if [[ ${#available_sources[@]} -eq 0 ]]; then
        echo -e "\n${COL_ERROR}ERROR:${RESET} No documentation tools available!"
        list_sources
        return 1
    fi
    
    # If source was specified via command line
    if [[ -n "$source_selected" ]]; then
        case "$source_selected" in
            "all")
                search_all_sources "$cmd"
                ;;
            "cheat"|"cheat-fuzzy")
                if command -v cheat &>/dev/null; then
                    fetch_from_source "cheat (fuzzy)" "$cmd"
                else
                    echo -e "${COL_ERROR}cheat is not installed!${RESET}"
                fi
                ;;
            "cheat-regex")
                if command -v cheat &>/dev/null; then
                    fetch_from_source "cheat (regex)" "$cmd"
                else
                    echo -e "${COL_ERROR}cheat is not installed!${RESET}"
                fi
                ;;
            "tldr")
                if command -v tldr &>/dev/null; then
                    fetch_from_source "tldr" "$cmd"
                else
                    echo -e "${COL_ERROR}tldr is not installed!${RESET}"
                fi
                ;;
            "cheat.sh")
                if command -v curl &>/dev/null; then
                    fetch_from_source "cheat.sh" "$cmd"
                else
                    echo -e "${COL_ERROR}curl is not installed!${RESET}"
                fi
                ;;
            "man")
                if command -v man &>/dev/null; then
                    fetch_from_source "man" "$cmd"
                else
                    echo -e "${COL_ERROR}man is not installed!${RESET}"
                fi
                ;;
            *)
                echo -e "${COL_ERROR}Unknown source: $source_selected${RESET}"
                echo -e "${COL_INFO}Available sources:${RESET}"
                for src in "${available_sources[@]}"; do
                    echo "  $src"
                done
                return 1
                ;;
        esac
        return 0
    fi
    
    # Interactive selection
    echo -e "\n${COL_RES}══════════════════════════════════════════════${RESET}"
    echo -e "${COL_ACCENT}Documentation for:${RESET} ${COL_RES}$cmd${RESET}"
    echo -e "${COL_RES}══════════════════════════════════════════════${RESET}"
    
    if [[ ${#available_sources[@]} -eq 1 ]]; then
        # Only one source available
        echo -e "${COL_INFO}Only ${available_sources[0]} available${RESET}\n"
        fetch_from_source "${available_sources[0]}" "$cmd"
        return 0
    fi
    
    # Multiple sources - interactive selection
    echo -e "${COL_USER}Select documentation source (1-${#available_sources[@]}):${RESET}\n"
    
    # Create a custom prompt for select
    PS3="$(echo -e "${COL_ACCENT}Enter your choice: ${RESET}")"
    select src in "${available_sources[@]}"; do
        if [[ -n "$src" ]] && [[ "$REPLY" =~ ^[0-9]+$ ]] && \
           [[ "$REPLY" -ge 1 ]] && [[ "$REPLY" -le ${#available_sources[@]} ]]; then
            echo ""
            break
        else
            echo -e "${COL_ERROR}Invalid choice. Please enter a number between 1 and ${#available_sources[@]}${RESET}"
        fi
    done
    
    # Execute based on selection
    if [[ "$src" == "ALL SOURCES (sequential)" ]]; then
        search_all_sources "$cmd"
    else
        fetch_from_source "$src" "$cmd"
    fi
}

# Main script execution
function main() {
    local command_to_search=""
    local source_selected=""
    local show_all_sources=false
    local list_sources_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -s|--source)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${COL_ERROR}ERROR:${RESET} --source requires an argument (tldr|cheat|man|cheat.sh|all)"
                    exit 1
                fi
                source_selected="$2"
                shift 2
                ;;
            -a|--all)
                show_all_sources=true
                shift
                ;;
            -l|--list)
                list_sources
                exit 0
                ;;
            --)
                shift
                command_to_search="$*"
                break
                ;;
            -*)
                echo -e "${COL_ERROR}ERROR:${RESET} Unknown option: $1"
                echo -e "Use ${COL_RES}./how.sh --help${RESET} for usage information"
                exit 1
                ;;
            *)
                if [[ -z "$command_to_search" ]]; then
                    command_to_search="$1"
                else
                    command_to_search="$command_to_search $1"
                fi
                shift
                ;;
        esac
    done
    
    # If no command provided, show last command
    if [[ -z "$command_to_search" ]]; then
        last_command
        exit 0
    fi
    
    if [[ ! "$command_to_search" =~ ^[[:print:]]+$ ]]; then
    echo -e "${COL_ERROR}SECURITY WARNING:${RESET} Command contains non-printable characters!"
    exit 1
    fi
    # Handle --all option
    if [[ "$show_all_sources" == true ]]; then
        search_all_sources "$command_to_search"
        exit 0
    fi
    
    # Get command information
    get_command_info "$command_to_search" "$source_selected"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
