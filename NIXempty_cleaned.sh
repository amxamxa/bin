#!/usr/bin/env bash
# auth:        _______max_kempter_________
# filename:    _______NIXempty.sh_____
# version: v0.2
# description: Advanced Nix store cleanup utility with safety checks
# changelog:   v0.2.0 - Added comprehensive help system
#              v0.1.0 - Performance optimizations, conditional df checks
# ============================================================================
# GLOBAL CONFIGURATION AND COLOR DEFINITIONS
# ============================================================================

# Enable strict error handling for better reliability
set -euo pipefail
IFS=$'\n\t'

# Color palette using ANSI escape codes
readonly SKY=""
readonly RED=""
readonly RASPBERRY=""
readonly GREEN=''
readonly YELLOW=''
readonly CYAN=''
readonly BLUE=''
readonly PINK=''
readonly NC=''  # No Color / Reset
readonly BOLD=''

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="v0.2"
readonly LOG_FILE="/tmp/nix-cleanup-$(date +%Y%m%d-%H%M%S).log"
readonly MIN_FREE_SPACE_GB=5  # Minimum free space required in GB
readonly DRY_RUN="${DRY_RUN:-false}"  # Can be overridden via environment
readonly CHECK_DISK="${CHECK_DISK:-true}"  # Control df checks
readonly DEBUG="${DEBUG:-false}"  # Debug output control

# ============================================================================
# HELP FUNCTIONS
# ============================================================================

# Display concise help text (shown when running without args or on error)
show_concise_help() {
    cat << EOF
NIXempty - Advanced Nix store cleanup utility

DESCRIPTION:
    Safely removes old Nix generations, runs garbage collection, and 
    optimizes the Nix store through deduplication.

USAGE:
    $SCRIPT_NAME [OPTIONS]
    
EXAMPLES:
    # Standard cleanup
    $SCRIPT_NAME
    
    # Dry-run mode (no changes)
    DRY_RUN=true $SCRIPT_NAME
    
    # Skip disk space checks for faster execution
    CHECK_DISK=false $SCRIPT_NAME

COMMON OPTIONS:
    -h, --help          Show detailed help information
    -v, --version       Display version information

ENVIRONMENT VARIABLES:
    DRY_RUN=true        Preview changes without executing
    CHECK_DISK=false    Skip disk space checks
    DEBUG=true          Enable verbose debug output

For complete documentation, run: $SCRIPT_NAME --help
EOF
}

# Display full help text with all details
show_full_help() {
    cat << EOF

           NIXempty - Nix Store Cleanup Utility           
                      Version $VERSION                       


NAME:
    NIXempty - Advanced Nix store cleanup utility with safety checks

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS]
    DRY_RUN=true $SCRIPT_NAME
    CHECK_DISK=false DEBUG=true $SCRIPT_NAME

DESCRIPTION:
    NIXempty is a comprehensive cleanup utility for NixOS and Nix package
    manager installations. It safely removes old system generations, runs
    garbage collection, and optimizes the Nix store through deduplication.

    The script includes multiple safety checks:
     Verifies sufficient disk space before cleanup
     Detects active Nix operations (builds, shells)
     Requires explicit user confirmation before proceeding
     Logs all operations for audit purposes
     Supports dry-run mode for safe testing

CLEANUP OPERATIONS:
    The script performs these operations in sequence:

    [1/4] Remove automatic GC roots
          Cleans up /nix/var/nix/gcroots/auto directory

    [2/4] Remove old generations
          Deletes user and system profile generations
          Command: nix-env --delete-generations old

    [3/4] Run garbage collection
          Removes unreferenced store paths
          Command: nix-collect-garbage -d

    [4/4] Optimize store
          Deduplicates files using hard links
          Command: nix-store --optimise

OPTIONS:
    -h, --help
          Display this comprehensive help message and exit.
          This flag takes precedence over all other arguments.

    -v, --version
          Display version information and exit.

ENVIRONMENT VARIABLES:
    DRY_RUN=true|false
          When set to 'true', the script will display what would be
          done without making any actual changes to the system.
          Useful for testing and previewing cleanup impact.
          
          Example: DRY_RUN=true $SCRIPT_NAME

    CHECK_DISK=true|false
          When set to 'false', skips disk space verification checks.
          This improves performance but removes a safety check.
          Default: true
          
          Example: CHECK_DISK=false $SCRIPT_NAME

    DEBUG=true|false
          When set to 'true', enables verbose debug output showing
          detailed information about each operation.
          Default: false
          
          Example: DEBUG=true $SCRIPT_NAME

EXAMPLES:
    # Basic usage (interactive confirmation required)
    $SCRIPT_NAME

    # Preview what would be cleaned without making changes
    DRY_RUN=true $SCRIPT_NAME

    # Fast cleanup with disk checks disabled
    CHECK_DISK=false $SCRIPT_NAME

    # Combine multiple options
    DRY_RUN=true DEBUG=true $SCRIPT_NAME

    # Run with sudo (recommended)
    sudo $SCRIPT_NAME

    # Show help (all equivalent)
    $SCRIPT_NAME -h
    $SCRIPT_NAME --help
    $SCRIPT_NAME --version --help  # help takes precedence

EXIT STATUS:
    0       Cleanup completed successfully
    1       Error occurred (check log file for details)

FILES:
    /tmp/nix-cleanup-YYYYMMDD-HHMMSS.log
          Detailed log file with timestamps for all operations.
          Location is displayed at script start.

    /nix/store
          The Nix store directory that will be cleaned.

    /nix/var/nix/gcroots/auto
          Automatic garbage collector roots directory.

    /nix/var/nix/profiles/system
          System profile directory (NixOS specific).

SAFETY FEATURES:
     Requires sudo privileges for safe execution
     Checks for minimum free disk space (${MIN_FREE_SPACE_GB}GB)
     Detects and warns about active Nix operations
     Requires explicit user confirmation before cleanup
     Comprehensive logging of all operations
     Graceful error handling with cleanup on exit

PERFORMANCE TIPS:
     Use CHECK_DISK=false to skip disk space verification
     Store size calculation can take time on large stores
     Optimization phase may be slow but saves significant space
     Consider running during low system activity

DEPENDENCIES:
    Required commands:
     du, numfmt, sudo, find, awk, xargs (coreutils)
     nix-collect-garbage, nix-store, nix-env (Nix)
     df (optional when CHECK_DISK=false)

ALIASES:
    The following aliases are available when sourcing the script:
     Nempty, NIXclean, Nclean, nixclean, nix-clean

AUTHOR:
    Max Kempter

REPORTING BUGS:
    Report issues via your preferred communication channel.

SEE ALSO:
    nix-collect-garbage(1), nix-store(1), nix-env(1)
    
COPYRIGHT:
    This is free software; see the source for copying conditions.

EOF
}

# Display version information
show_version() {
    cat << EOF
NIXempty version $VERSION
Advanced Nix store cleanup utility

Copyright (c) Max Kempter
This is free software; see the source for copying conditions.
EOF
}

# Parse command line arguments
parse_arguments() {
    # Check for help flags first (they take precedence)
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                show_full_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
        esac
    done
    
    # If any unrecognized arguments, show concise help and exit
    if [[ $# -gt 0 ]]; then
        echo -e "${RED}Error: Unknown argument(s): $*\n" >&2
        show_concise_help
        exit 1
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Logging function with timestamp and level support
# Usage: log_message "INFO" "Message text"
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Display to console with appropriate color
    case "$level" in
        ERROR)   echo -e "${RED} $message" >&2 ;;
        WARNING) echo -e "  $message" ;;
        INFO)    echo -e "  $message" ;;
        SUCCESS) echo -e "${GREEN} $message" ;;
        DEBUG)   [[ "$DEBUG" == "true" ]] && echo -e "${BLUE} $message" ;;
    esac
}

# Error handler with cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "Script terminated with exit code: $exit_code"
        echo -e "\n${RED} Cleanup interrupted! Check log: $LOG_FILE"
    fi
}

# Register cleanup function for various signals
trap cleanup_on_exit EXIT INT TERM

# Check if running with proper privileges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_message "WARNING" "Running as root directly. Consider using sudo instead."
    elif ! sudo -n true 2>/dev/null; then
        log_message "ERROR" "This script requires sudo privileges"
        echo -e "Please run: sudo -v"
        return 1
    fi
}

# Verify all required commands are available
check_dependencies() {
    local missing=()
    local required_cmds=(
        "du"                  # Disk usage calculation
        "numfmt"              # Human-readable size formatting
        "sudo"                # Privilege escalation
        "nix-collect-garbage" # Nix garbage collection
        "nix-store"           # Store optimization
        "find"                # File system operations
        "awk"                 # Text processing
        "xargs"               # Parallel operations
    )
    
    # df is optional when CHECK_DISK=false
    if [[ "$CHECK_DISK" == "true" ]]; then
        required_cmds+=("df")
    fi
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if (( ${#missing[@]} > 0 )); then
        log_message "ERROR" "Missing required commands: ${missing[*]}"
        echo -e "Install missing tools via nix-env or configuration.nix"
        return 1
    fi
    
    log_message "INFO" "All dependencies satisfied"
    return 0
}

# Check available disk space before cleanup (OPTIMIZED)
# Only runs when CHECK_DISK=true
check_disk_space() {
    # Skip if disabled
    if [[ "$CHECK_DISK" == "false" ]]; then
        log_message "INFO" "Disk space check disabled (CHECK_DISK=false)"
        return 0
    fi
    
    local available_gb
    if ! available_gb=$(df /nix/store 2>/dev/null | awk 'NR==2 {print int($4/1048576)}'); then
        log_message "WARNING" "Could not determine disk space"
        return 0  # Continue anyway
    fi
    
    if [[ -z "$available_gb" ]]; then
        log_message "WARNING" "Disk space check returned empty result"
        return 0
    fi
    
    if [[ $available_gb -lt $MIN_FREE_SPACE_GB ]]; then
        log_message "WARNING" "Low disk space: ${available_gb}GB available"
        echo -e "Consider freeing space manually first"
        return 1
    fi
    
    log_message "INFO" "Available disk space: ${available_gb}GB"
    return 0
}

# Get store size with error handling and fallback (OPTIMIZED)
# Returns size in bytes or uses df-based estimation
get_store_size() {
    local size_bytes
    
    log_message "DEBUG" "Calculating store size..."
    
    # Primary method: du with timeout and max-depth optimization
    if size_bytes=$(timeout 30 du -sb --max-depth=0 /nix/store 2>/dev/null | awk '{print $1}'); then
        if [[ "$size_bytes" =~ ^[0-9]+$ ]] && [[ $size_bytes -gt 0 ]]; then
            log_message "DEBUG" "Store size calculated via du: $size_bytes bytes"
            echo "$size_bytes"
            return 0
        fi
    fi
    
    # Fallback: df-based estimation (faster but less accurate)
    log_message "WARNING" "du failed, using df-based estimation"
    
    if command -v df >/dev/null 2>&1; then
        local used_kb
        if used_kb=$(df /nix/store 2>/dev/null | awk 'NR==2 {print $3}'); then
            if [[ "$used_kb" =~ ^[0-9]+$ ]] && [[ $used_kb -gt 0 ]]; then
                size_bytes=$((used_kb * 1024))
                log_message "WARNING" "Using df estimation: $size_bytes bytes"
                echo "$size_bytes"
                return 0
            fi
        fi
    fi
    
    # Last resort: return error
    log_message "ERROR" "Failed to calculate store size"
    echo "-1"
    return 1
}

# Display formatted header with version info
print_header() {
    echo -e "${PINK}\t____________________________________________________"
    echo -e "\t______________________________________________________"
    echo -e "\t/_____/_____/_____/_____/_____/_____/_____/_____/_____/"
    echo -e "\t         _____/ /__  ____ _____  ___  _____     "
    echo -e "\t        / ___/ / _ \/ __ // __ \/ _ \/ ___/     "
    echo -e "\t      / /__/ /  __/ /_/ / / / /  __/ /    "
    echo -e "\t      \___/_/\___/\__,_/_/ /_/\___/_/    "
    echo -e "\t______________________________________________________"
    echo -e "\t_/_____/_____/_____/_____/_____/_____/_____/_____/_____/"
    echo -e "${PINK}\n\t=== Nix Store Cleaner v${VERSION} ==="
    echo -e "\t____________________________________________________\n"
    echo -e "${BLUE}Log file: $LOG_FILE"
    
    # Show active options
    if [[ "$DRY_RUN" == "true" ]] || [[ "$CHECK_DISK" == "false" ]] || [[ "$DEBUG" == "true" ]]; then
        echo -e "Active options:"
        [[ "$DRY_RUN" == "true" ]] && echo -e "   DRY_RUN enabled"
        [[ "$CHECK_DISK" == "false" ]] && echo -e "   Disk space check disabled"
        [[ "$DEBUG" == "true" ]] && echo -e "   Debug mode enabled"
    fi
    echo ""
}

# ============================================================================
# MAIN CLEANUP FUNCTION
# ============================================================================

NIXempty() {
    # Parse command line arguments (help flags handled here)
    parse_arguments "$@"
    
    # Initialize logging
    log_message "INFO" "Starting Nix Store Cleaner v${VERSION}"
    log_message "INFO" "Configuration: DRY_RUN=$DRY_RUN, CHECK_DISK=$CHECK_DISK, DEBUG=$DEBUG"
    
    # Display header
    print_header
    
    # Perform prerequisite checks
    if ! check_privileges; then
        return 1
    fi
    
    if ! check_dependencies; then
        return 1
    fi
    
    if ! check_disk_space; then
        echo -e "Continue anyway? Low disk space detected."
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            read -q "REPLY? Proceed despite low disk space? (y/N) "
            echo
        else
            read -r -p " Proceed despite low disk space? (y/N) " REPLY
        fi
        
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_message "INFO" "User cancelled due to low disk space"
            return 0
        fi
    fi
    
    # Check for active Nix builds (ENHANCED)
    if pgrep -f "nix-build|nix-shell|nixos-rebuild|nix-env|nix-instantiate" >/dev/null 2>&1; then
        log_message "WARNING" "Active Nix operations detected"
        echo -e "  Active Nix operations detected:"
        pgrep -fa "nix-" | grep -v "$SCRIPT_NAME" | sed 's/^/   /' | head -n 5 || true
        echo -e "Cleanup during builds may cause issues."
        
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            read -q "REPLY? Continue anyway? (y/N) "
            echo
        else
            read -r -p " Continue anyway? (y/N) " REPLY
        fi
        
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_message "INFO" "User cancelled due to active operations"
            return 0
        fi
    fi
    
    # Get initial store size
    echo -e " Analyzing Nix store..."
    local before_bytes
    before_bytes=$(get_store_size)
    
    if [[ $before_bytes -eq -1 ]]; then
        echo -e "${RED} Failed to determine store size"
        echo -e "Continue without size tracking?"
        
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            read -q "REPLY? Continue? (y/N) "
            echo
        else
            read -r -p " Continue? (y/N) " REPLY
        fi
        
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            return 1
        fi
        before_bytes=0  # Continue without tracking
    fi
    
    local before_hr
    before_hr=$(numfmt --to=iec --suffix=B "$before_bytes" 2>/dev/null || echo "Unknown")
    echo -e "Current Nix store size: ${BLUE}${before_hr}"
    log_message "INFO" "Initial store size: $before_hr ($before_bytes bytes)"
    
    # Count profiles and generations for informational purposes
    local profile_count generation_count store_paths
    profile_count=$(find /nix/var/nix/profiles -maxdepth 1 -type l 2>/dev/null | wc -l)
    generation_count=$(sudo nix-env --list-generations 2>/dev/null | wc -l)
    store_paths=$(find /nix/store -maxdepth 1 -type d 2>/dev/null | wc -l)
    
    echo -e "\n System information:"
    echo -e "   Profiles: ${profile_count}"
    echo -e "   Generations: ${generation_count}"
    echo -e "   Store paths: ${store_paths}"
    
    # Dry run mode check
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n DRY RUN MODE - No changes will be made"
        log_message "INFO" "Running in dry-run mode"
    fi
    
    # Safety confirmation with detailed warning
    echo -e "\n${RED}  WARNING: This operation will:"
    echo -e "   Remove ALL old system generations"
    echo -e "   Delete unreferenced store paths"
    echo -e "   Cannot be undone"
    echo -e "\n Tip: Consider creating a backup first"
    
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        read -q "REPLY? Proceed with cleanup? (y/N) "
        echo
    else
        read -r -p " Proceed with cleanup? (y/N) " REPLY
    fi
    
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_message "INFO" "User cancelled cleanup"
        echo -e "\n${GREEN} Cleanup cancelled. No changes made."
        return 0
    fi
    
    echo -e "\n${GREEN} Starting cleanup operations..."
    log_message "INFO" "User confirmed cleanup"
    
    # ========================================================================
    # CLEANUP PHASE 1: Remove automatic GC roots (OPTIMIZED)
    # ========================================================================
    
    local auto_roots="/nix/var/nix/gcroots/auto"
    if [[ -d "$auto_roots" ]]; then
        echo -e "\n[1/4] Removing automatic GC roots..."
        local roots_count
        roots_count=$(sudo find "$auto_roots" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        
        if (( roots_count > 0 )); then
            log_message "INFO" "Found $roots_count GC roots to remove"
            
            if [[ "$DRY_RUN" != "true" ]]; then
                # Parallel removal with xargs for better performance
                log_message "DEBUG" "Removing broken symlinks in parallel"
                sudo find "$auto_roots" -type l -xtype l -print0 2>/dev/null | \
                    xargs -0 -r -P4 rm -f 2>/dev/null || true
                
                log_message "DEBUG" "Removing remaining GC roots in parallel"
                sudo find "$auto_roots" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | \
                    xargs -0 -r -P4 rm -rf 2>/dev/null || true
            fi
            
            echo -e "${GREEN}   Removed ${roots_count} GC roots"
        else
            echo -e "${BLUE}   No GC roots to remove"
        fi
    else
        log_message "WARNING" "GC roots directory not found: $auto_roots"
        echo -e "   GC roots directory not found"
    fi
    
    # ========================================================================
    # CLEANUP PHASE 2: Remove old generations
    # ========================================================================
    
    echo -e "\n[2/4] Removing old generations..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Remove user profile generations
        if sudo nix-env --delete-generations old 2>/dev/null; then
            echo -e "${GREEN}   User generations cleaned"
            log_message "INFO" "User generations removed"
        else
            echo -e "   No user generations to remove"
            log_message "INFO" "No user generations found"
        fi
        
        # Remove system profile generations (NixOS specific)
        if [[ -d /nix/var/nix/profiles/system ]]; then
            if sudo nix-env -p /nix/var/nix/profiles/system --delete-generations old 2>/dev/null; then
                echo -e "${GREEN}   System generations cleaned"
                log_message "INFO" "System generations removed"
            else
                echo -e "   No system generations to remove"
                log_message "INFO" "No system generations found"
            fi
        fi
    else
        echo -e "${BLUE}   Skipped in dry-run mode"
    fi
    
    # ========================================================================
    # CLEANUP PHASE 3: Run garbage collection
    # ========================================================================
    
    echo -e "\n[3/4] Running garbage collection..."
    log_message "INFO" "Starting garbage collection"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Run with delete all generations flag
        local gc_output
        if gc_output=$(sudo nix-collect-garbage -d 2>&1 | tee -a "$LOG_FILE"); then
            # Extract and display freed space
            local freed_info
            freed_info=$(echo "$gc_output" | grep -E "freed|deleted" | head -n 1 || echo "")
            
            if [[ -n "$freed_info" ]]; then
                echo -e "${GREEN}   $freed_info"
                log_message "SUCCESS" "Garbage collection: $freed_info"
            else
                echo -e "${GREEN}   Garbage collection completed"
                log_message "INFO" "Garbage collection completed"
            fi
        else
            echo -e "   Nothing to collect"
            log_message "INFO" "No garbage to collect"
        fi
    else
        echo -e "${BLUE}   Skipped in dry-run mode"
    fi
    
    # ========================================================================
    # CLEANUP PHASE 4: Optimize store (deduplication)
    # ========================================================================
    
    echo -e "\n[4/4] Optimizing store (deduplication)..."
    log_message "INFO" "Starting store optimization"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Store optimization can save significant space via hard links
        local optimize_output
        if optimize_output=$(sudo nix-store --optimise 2>&1); then
            local saved_bytes saved_hr
            
            # Try to extract bytes freed
            saved_bytes=$(echo "$optimize_output" | grep -oP '\d+(?= bytes freed)' || echo "0")
            
            if [[ $saved_bytes -gt 0 ]]; then
                saved_hr=$(numfmt --to=iec --suffix=B "$saved_bytes" 2>/dev/null || echo "${saved_bytes}B")
                echo -e "${GREEN}   Optimization saved: $saved_hr"
                log_message "SUCCESS" "Store optimization saved: $saved_hr"
            else
                echo -e "${BLUE}   Store already optimized"
                log_message "INFO" "Store already optimized"
            fi
        else
            log_message "WARNING" "Store optimization failed"
            echo -e "   Optimization failed (non-critical)"
        fi
    else
        echo -e "${BLUE}   Skipped in dry-run mode"
    fi
    
    # ========================================================================
    # RESULTS CALCULATION AND DISPLAY
    # ========================================================================
    
    echo -e "\n Calculating results..."
    
    # Get final store size
    local after_bytes
    after_bytes=$(get_store_size)
    
    if [[ $after_bytes -eq -1 ]] || [[ $before_bytes -eq 0 ]]; then
        log_message "WARNING" "Could not verify final store size"
        echo -e "\n"
        echo -e "${PINK} CLEANUP COMPLETE!"
        echo -e ""
        echo -e "  Size tracking unavailable"
        echo -e "  ${GREEN}Operations completed successfully"
        echo -e ""
        
        log_message "SUCCESS" "Cleanup completed (size tracking unavailable)"
        echo -e "\n${BLUE} Full log available at: $LOG_FILE"
        return 0
    fi
    
    # Calculate space saved
    local saved_bytes=$((before_bytes - after_bytes))
    
    # Ensure non-negative value
    if (( saved_bytes < 0 )); then
        saved_bytes=0
        log_message "WARNING" "Store size increased (possibly due to concurrent operations)"
    fi
    
    local after_hr saved_hr
    after_hr=$(numfmt --to=iec --suffix=B "$after_bytes")
    saved_hr=$(numfmt --to=iec --suffix=B "$saved_bytes")
    
    # Calculate percentage saved
    local percent_saved=0
    if (( before_bytes > 0 )); then
        percent_saved=$(( (saved_bytes * 100) / before_bytes ))
    fi
    
    # Display results summary
    echo -e "\n"
    echo -e "${PINK} CLEANUP COMPLETE!"
    echo -e ""
    echo -e "  Before: ${RED}$before_hr"
    echo -e "  After:  ${GREEN}$after_hr"
    echo -e "  Saved:  ${GREEN}$saved_hr (${percent_saved}%)"
    echo -e ""
    
    log_message "SUCCESS" "Cleanup completed. Saved: $saved_hr"
    log_message "INFO" "Final store size: $after_hr ($after_bytes bytes)"
    
    # Send desktop notification if available
    if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        notify-send \
            "Nix Store Cleanup Complete" \
            "Freed $saved_hr (${percent_saved}%)\nNew size: $after_hr" \
            --icon=package-x-generic \
            --urgency=normal \
            2>/dev/null || true
    fi
    
    echo -e "\n${BLUE} Full log available at: $LOG_FILE"
    
    # Optional: Suggest next steps
    if (( saved_bytes < 104857600 )); then  # Less than 100MB saved
        echo -e "\n Tip: Consider running 'nix-store --verify --check-contents' to verify store integrity"
    fi
    
    # Show usage hints
    if [[ "$CHECK_DISK" == "true" ]] || [[ "$DRY_RUN" == "false" ]]; then
        echo -e "\n Performance tips:"
        [[ "$CHECK_DISK" == "true" ]] && echo -e "   Skip disk checks: CHECK_DISK=false $SCRIPT_NAME"
        [[ "$DRY_RUN" == "false" ]] && echo -e "   Dry-run mode: DRY_RUN=true $SCRIPT_NAME"
        echo -e "   Debug mode: DEBUG=true $SCRIPT_NAME"
        echo -e "   Show help: $SCRIPT_NAME --help"
    fi
    
    return 0
}

# ============================================================================
# COMMAND ALIASES FOR CONVENIENCE
# ============================================================================

# Register multiple aliases for user convenience
alias Nempty='NIXempty'
alias NIXclean='NIXempty'
alias Nclean='NIXempty'
alias nixclean='NIXempty'
alias nix-clean='NIXempty'

# ============================================================================
# MAIN EXECUTION (if run directly)
# ============================================================================

# Execute if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    NIXempty "$@"
fi
