#!/usr/bin/env bash
#!/usr/bin/env bash
#===============================================================================
# TITLE:        NIXempty.sh - Advanced Nix Store Cleanup Utility
# AUTHOR:       max_kempter
# VERSION:      v0.2.1
# DESCRIPTION:  Comprehensive Nix store cleanup with safety checks and logging
# CHANGELOG:    v0.2.1 - Added command prefix to avoid alias conflicts
#               v0.2.0 - Added comprehensive help system
#               v0.1.0 - Performance optimizations, conditional df checks
#===============================================================================

#-------------------------------------------------------------------------------
# SECTION 1: STRICT MODE AND GLOBAL CONFIGURATION
#-------------------------------------------------------------------------------

# Enable strict error handling for better reliability
set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------------------------------
# SECTION 2: COLOR PALETTE (ANSI ESCAPE CODES)
#-------------------------------------------------------------------------------

readonly SKY="\033[38;2;62;36;129m\033[48;2;135;206;235m"
readonly RED="\033[38;2;240;128;128m\033[48;2;139;0;0m"
readonly RASPBERRY="\033[38;2;32;0;21m\033[48;2;221;160;221m"
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly PINK='\033[0;35m'
readonly NC='\033[0m'  # No Color / Reset

#-------------------------------------------------------------------------------
# SECTION 3: SCRIPT CONFIGURATION
#-------------------------------------------------------------------------------

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="v0.2.1"
readonly LOG_FILE="/tmp/nix-cleanup-$(date +%Y%m%d-%H%M%S).log"
readonly MIN_FREE_SPACE_GB=5  # Minimum free space required in GB

# Custom exit codes (avoiding Nix and system reserved codes)
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_ARG=10
readonly EXIT_DEPENDENCY_MISSING=11
readonly EXIT_INSUFFICIENT_PRIVILEGES=12
readonly EXIT_INSUFFICIENT_SPACE=13
readonly EXIT_NIX_OPERATION_ACTIVE=14
readonly EXIT_USER_CANCELLED=15
readonly EXIT_DRY_RUN=16

#-------------------------------------------------------------------------------
# SECTION 4: UTILITY FUNCTIONS
#-------------------------------------------------------------------------------

# FUNCTION: log_message
# DESCRIPTION: Log messages with timestamp and level support
# RETURNS: Nothing (outputs to stderr and log file)
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(command date '+%Y-%m-%d %H:%M:%S')
    
    # Define color based on level
    local color=""
    local symbol=""
    case "$level" in
        ERROR)     color="$RED"     symbol="✗";;
        WARNING)   color="$YELLOW"  symbol="⚠";;
        INFO)      color="$CYAN"    symbol="ℹ";;
        SUCCESS)   color="$GREEN"   symbol="✓";;
        DEBUG)     color="$PINK"    symbol="🐛";;
        *)         color="$NC"      symbol="•";;
    esac
    
    # Format output
    local output="[$timestamp] [$level] $message"
    
    # Print to stderr with colors
    if [[ -t 2 ]]; then
        >&2 echo -e "${color}${symbol} ${message}${NC}"
    else
        >&2 echo "$output"
    fi
    
    # Always write to log file without colors
    echo "$output" >> "$LOG_FILE"
}

# FUNCTION: cleanup_on_exit
# DESCRIPTION: Cleanup handler for script exit
# RETURNS: Nothing
cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -eq $EXIT_SUCCESS ]]; then
        log_message "SUCCESS" "Script completed successfully"
    else
        log_message "ERROR" "Script exited with code $exit_code"
    fi
    
    log_message "INFO" "Log file saved to: $LOG_FILE"
    
    # Remove trap to prevent infinite recursion
    trap - EXIT INT TERM
    exit $exit_code
}

# Register cleanup handler
trap cleanup_on_exit EXIT INT TERM

# FUNCTION: check_privileges
# DESCRIPTION: Check if running with proper privileges
# RETURNS: 0 if privileges are sufficient, non-zero otherwise
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_message "WARNING" "Running as root is not recommended for Nix operations"
        log_message "INFO" "Please run as regular user with sudo privileges"
        return $EXIT_INSUFFICIENT_PRIVILEGES
    fi
    
    # Check for sudo access
    if ! command sudo -n true 2>/dev/null; then
        log_message "INFO" "Need sudo privileges for some operations"
        command echo "Please enter your password if prompted:"
        if ! command sudo -v; then
            log_message "ERROR" "Failed to acquire sudo privileges"
            return $EXIT_INSUFFICIENT_PRIVILEGES
        fi
    fi
    
    return $EXIT_SUCCESS
}

# FUNCTION: check_dependencies
# DESCRIPTION: Verify all required commands are available
# RETURNS: 0 if all dependencies are met, non-zero otherwise
check_dependencies() {
    local missing_deps=()
    local deps=("du" "df" "find" "xargs" "awk" "grep" "sed" "numfmt" "pgrep" "timeout")
    
    # Add Nix-specific dependencies
    deps+=("nix-env" "nix-collect-garbage" "nix-store")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing dependencies: ${missing_deps[*]}"
        return $EXIT_DEPENDENCY_MISSING
    fi
    
    log_message "SUCCESS" "All dependencies are available"
    return $EXIT_SUCCESS
}

# FUNCTION: check_disk_space
# DESCRIPTION: Check available disk space before cleanup
# PARAMETERS: $1 - Skip check flag (true/false)
# RETURNS: 0 if sufficient space, non-zero otherwise
check_disk_space() {
    local skip_check="${1:-false}"
    
    if [[ "$skip_check" == "true" ]]; then
        log_message "INFO" "Disk space check skipped"
        return $EXIT_SUCCESS
    fi
    
    local available_bytes
    available_bytes=$(command df -B1 /nix 2>/dev/null | command awk 'NR==2 {print $4}')
    
    if [[ -z "$available_bytes" ]]; then
        log_message "WARNING" "Could not determine available disk space"
        return $EXIT_SUCCESS  # Continue anyway
    fi
    
    local available_gb=$((available_bytes / 1024 / 1024 / 1024))
    
    if [[ $available_gb -lt $MIN_FREE_SPACE_GB ]]; then
        log_message "WARNING" "Low disk space: ${available_gb}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)"
        log_message "INFO" "Consider freeing up space before proceeding"
        return $EXIT_INSUFFICIENT_SPACE
    fi
    
    log_message "SUCCESS" "Disk space check passed: ${available_gb}GB available"
    return $EXIT_SUCCESS
}

# FUNCTION: get_store_size
# DESCRIPTION: Get store size with error handling and fallback
# RETURNS: Size in bytes (output to stdout), 0 on success
get_store_size() {
    local size_bytes
    
    # Try du with timeout (most accurate)
    if size_bytes=$(command timeout 30s command du -sb /nix/store 2>/dev/null | command awk '{print $1}'); then
        if [[ -n "$size_bytes" ]]; then
            echo "$size_bytes"
            return $EXIT_SUCCESS
        fi
    fi
    
    # Fallback: Use df estimation
    log_message "WARNING" "Using fallback method for store size calculation"
    if size_bytes=$(command df -B1 /nix/store 2>/dev/null | command awk 'NR==2 {print $3}'); then
        echo "$size_bytes"
        return $EXIT_SUCCESS
    fi
    
    # Last resort: return 0
    log_message "ERROR" "Could not determine store size"
    echo "0"
    return $EXIT_GENERAL_ERROR
}

# FUNCTION: print_header
# DESCRIPTION: Display formatted header with version info
# RETURNS: Nothing
print_header() {
    local dry_run="$1"
    local check_disk="$2"
    local debug="$3"
    
    clear
    echo -e "${SKY}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${SKY}║                                                          ║${NC}"
    echo -e "${SKY}║           NIX STORE CLEANUP UTILITY $VERSION             ║${NC}"
    echo -e "${SKY}║                                                          ║${NC}"
    echo -e "${SKY}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Log file:${NC} $LOG_FILE"
    echo -e "${CYAN}Options:${NC}"
    echo -e "  ${YELLOW}•${NC} Dry-run mode: ${dry_run:-false}"
    echo -e "  ${YELLOW}•${NC} Disk check: ${check_disk:-true}"
    echo -e "  ${YELLOW}•${NC} Debug mode: ${debug:-false}"
    echo
}

#-------------------------------------------------------------------------------
# SECTION 5: HELP SYSTEM
#-------------------------------------------------------------------------------

show_help() {
    cat << EOF
${CYAN}NIXempty.sh - Advanced Nix Store Cleanup Utility${NC}

${GREEN}DESCRIPTION:${NC}
    Comprehensive Nix store cleanup tool with safety checks, logging,
    and multiple cleanup phases. Designed to safely recover disk space
    from Nix store while maintaining system stability.

${GREEN}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${GREEN}EXAMPLES:${NC}
    # Standard cleanup with all checks
    $SCRIPT_NAME
    
    # Dry-run to see what would be cleaned
    $SCRIPT_NAME --dry-run
    
    # Skip disk space check
    $SCRIPT_NAME --no-disk-check
    
    # Enable debug output
    $SCRIPT_NAME --debug

${GREEN}OPTIONS:${NC}
    -h, --help          Show this help message
    -v, --version       Show version information
    -d, --dry-run       Simulate cleanup without making changes
    -n, --no-disk-check Skip disk space verification
    --debug             Enable debug output
    --force             Skip confirmation prompts (use with caution!)

${GREEN}CLEANUP PHASES:${NC}
    1. Remove old GC roots from /nix/var/nix/gcroots/auto
    2. Delete old user and system generations
    3. Run nix-collect-garbage
    4. Optimize store (deduplicate with hardlinks)

${GREEN}EXIT CODES:${NC}
    0   Success
    1   General error
    10  Invalid argument
    11  Missing dependency
    12  Insufficient privileges
    13  Insufficient disk space
    14  Nix operation active
    15  User cancelled
    16  Dry run completed

${GREEN}AUTHOR:${NC}
    Max Kempter <max.kempter@example.com>
EOF
    exit $EXIT_SUCCESS
}

show_version() {
    echo "NIXempty.sh version $VERSION"
    exit $EXIT_SUCCESS
}

#-------------------------------------------------------------------------------
# SECTION 6: MAIN CLEANUP FUNCTION
#-------------------------------------------------------------------------------

NIXempty() {
    # Parse command line arguments
    local dry_run=false
    local check_disk=true
    local debug=false
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--version)
                show_version
                ;;
            -d|--dry-run)
                dry_run=true
                log_message "INFO" "Dry-run mode enabled"
                shift
                ;;
            -n|--no-disk-check)
                check_disk=false
                log_message "INFO" "Disk check disabled"
                shift
                ;;
            --debug)
                debug=true
                log_message "DEBUG" "Debug mode enabled"
                shift
                ;;
            --force)
                force=true
                log_message "WARNING" "Force mode enabled - skipping confirmations"
                shift
                ;;
            *)
                log_message "ERROR" "Unknown option: $1"
                show_help
                ;;
        esac
    done
    
    # Initialize logging
    log_message "INFO" "Starting Nix store cleanup"
    log_message "INFO" "Script version: $VERSION"
    log_message "INFO" "Log file: $LOG_FILE"
    
    # Show header
    print_header "$dry_run" "$check_disk" "$debug"
    
    #---------------------------------------------------------------------------
    # PHASE 0: PRE-CHECKS
    #---------------------------------------------------------------------------
    
    log_message "INFO" "Phase 0: Running pre-checks"
    
    # Check dependencies
    if ! check_dependencies; then
        return $EXIT_DEPENDENCY_MISSING
    fi
    
    # Check privileges
    if ! check_privileges; then
        return $EXIT_INSUFFICIENT_PRIVILEGES
    fi
    
    # Check disk space
    if ! check_disk_space "$check_disk"; then
        return $EXIT_INSUFFICIENT_SPACE
    fi
    
    # Check for active Nix operations
    if command pgrep -f "nix-daemon|nix-build|nix-shell" >/dev/null 2>&1; then
        log_message "ERROR" "Active Nix operations detected. Please wait for them to complete."
        return $EXIT_NIX_OPERATION_ACTIVE
    fi
    
    # Get initial store size
    log_message "INFO" "Calculating initial store size..."
    local initial_size_bytes
    initial_size_bytes=$(get_store_size)
    local initial_size_human
    initial_size_human=$(command numfmt --to=iec --suffix=B "$initial_size_bytes")
    
    log_message "SUCCESS" "Initial store size: $initial_size_human"
    
    #---------------------------------------------------------------------------
    # PHASE 1: SAFETY CONFIRMATION
    #---------------------------------------------------------------------------
    
    if [[ "$force" != "true" ]]; then
        echo -e "${YELLOW}⚠  WARNING: This will perform the following actions:${NC}"
        echo -e "   • Remove old GC roots from /nix/var/nix/gcroots/auto"
        echo -e "   • Delete old user and system generations"
        echo -e "   • Run nix-collect-garbage (may remove unused packages)"
        echo -e "   • Optimize store with deduplication"
        echo
        echo -e "${RED}⚠  This action cannot be undone!${NC}"
        echo
        
        # Handle different shells
        if [[ -n "$ZSH_VERSION" ]]; then
            read -q "REPLY?Continue? (y/N): "
            echo
        else
            read -rp "Continue? (y/N): " -t 30 -n 1 REPLY
            echo
        fi
        
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Cleanup cancelled by user"
            return $EXIT_USER_CANCELLED
        fi
    fi
    
    #---------------------------------------------------------------------------
    # PHASE 2: REMOVE OLD GC ROOTS
    #---------------------------------------------------------------------------
    
    log_message "INFO" "Phase 1: Removing old GC roots"
    
    local gcroots_dir="/nix/var/nix/gcroots/auto"
    if [[ -d "$gcroots_dir" ]]; then
        # Find broken symlinks
        local broken_links=()
        while IFS= read -r -d $'\0' link; do
            broken_links+=("$link")
        done < <(command find "$gcroots_dir" -type l ! -exec test -e {} \; -print0 2>/dev/null)
        
        # Find all symlinks
        local all_links=()
        while IFS= read -r -d $'\0' link; do
            all_links+=("$link")
        done < <(command find "$gcroots_dir" -type l -print0 2>/dev/null)
        
        log_message "INFO" "Found ${#broken_links[@]} broken links and ${#all_links[@]} total links"
        
        if [[ ${#all_links[@]} -gt 0 ]]; then
            if [[ "$dry_run" == "true" ]]; then
                log_message "INFO" "[DRY-RUN] Would remove ${#all_links[@]} GC roots"
            else
                # Remove broken links first
                for link in "${broken_links[@]}"; do
                    command rm -f "$link" 2>/dev/null && \
                    log_message "SUCCESS" "Removed broken link: $(basename "$link")"
                done
                
                # Remove remaining links
                for link in "${all_links[@]}"; do
                    if [[ -e "$link" ]]; then
                        command rm -f "$link" 2>/dev/null && \
                        log_message "SUCCESS" "Removed GC root: $(basename "$link")"
                    fi
                done
            fi
        else
            log_message "INFO" "No GC roots found to remove"
        fi
    else
        log_message "WARNING" "GC roots directory not found: $gcroots_dir"
    fi
    
    #---------------------------------------------------------------------------
    # PHASE 3: DELETE OLD GENERATIONS
    #---------------------------------------------------------------------------
    
    log_message "INFO" "Phase 2: Deleting old generations"
    
    if [[ "$dry_run" == "true" ]]; then
        log_message "INFO" "[DRY-RUN] Would delete old user generations"
        log_message "INFO" "[DRY-RUN] Would delete old system generations (if on NixOS)"
    else
        # Delete old user generations
        if command nix-env --delete-generations old 2>> "$LOG_FILE"; then
            log_message "SUCCESS" "Deleted old user generations"
        else
            log_message "WARNING" "Failed to delete user generations"
        fi
        
        # Delete system generations (NixOS only)
        if [[ -f /run/current-system/nixos-version ]]; then
            if command sudo nix-env -p /nix/var/nix/profiles/system --delete-generations old 2>> "$LOG_FILE"; then
                log_message "SUCCESS" "Deleted old system generations"
            else
                log_message "WARNING" "Failed to delete system generations"
            fi
        fi
    fi
    
    #---------------------------------------------------------------------------
    # PHASE 4: RUN GARBAGE COLLECTION
    #---------------------------------------------------------------------------
    
    log_message "INFO" "Phase 3: Running garbage collection"
    
    if [[ "$dry_run" == "true" ]]; then
        log_message "INFO" "[DRY-RUN] Would run: nix-collect-garbage -d"
    else
        log_message "INFO" "Running nix-collect-garbage..."
        if command nix-collect-garbage -d 2>&1 | tee -a "$LOG_FILE"; then
            log_message "SUCCESS" "Garbage collection completed"
        else
            log_message "ERROR" "Garbage collection failed"
        fi
    fi
    
    #---------------------------------------------------------------------------
    # PHASE 5: OPTIMIZE STORE
    #---------------------------------------------------------------------------
    
    log_message "INFO" "Phase 4: Optimizing store (deduplication)"
    
    if [[ "$dry_run" == "true" ]]; then
        log_message "INFO" "[DRY-RUN] Would run: nix-store --optimise"
    else
        log_message "INFO" "Running nix-store --optimise..."
        if command nix-store --optimise 2>&1 | tee -a "$LOG_FILE"; then
            log_message "SUCCESS" "Store optimization completed"
        else
            log_message "WARNING" "Store optimization may have encountered warnings"
        fi
    fi
    
    #---------------------------------------------------------------------------
    # PHASE 6: CALCULATE RESULTS
    #---------------------------------------------------------------------------
    
    log_message "INFO" "Calculating results..."
    
    local final_size_bytes
    final_size_bytes=$(get_store_size)
    local final_size_human
    final_size_human=$(command numfmt --to=iec --suffix=B "$final_size_bytes")
    
    local saved_bytes=$((initial_size_bytes - final_size_bytes))
    local saved_human
    saved_human=$(command numfmt --to=iec --suffix=B "$saved_bytes")
    
    local percentage_saved=0
    if [[ $initial_size_bytes -gt 0 ]]; then
        percentage_saved=$((saved_bytes * 100 / initial_size_bytes))
    fi
    
    #---------------------------------------------------------------------------
    # PHASE 7: DISPLAY SUMMARY
    #---------------------------------------------------------------------------
    
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    CLEANUP COMPLETE                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Initial store size:${NC}  $initial_size_human"
    echo -e "${CYAN}Final store size:${NC}    $final_size_human"
    echo -e "${CYAN}Space reclaimed:${NC}     $saved_human (${percentage_saved}%)"
    echo
    echo -e "${YELLOW}📊 Summary:${NC}"
    echo -e "  ${GREEN}✓${NC} GC roots cleaned"
    echo -e "  ${GREEN}✓${NC} Old generations deleted"
    echo -e "  ${GREEN}✓${NC} Garbage collection performed"
    echo -e "  ${GREEN}✓${NC} Store optimized (deduplicated)"
    echo
    echo -e "${YELLOW}💡 Tips for further optimization:${NC}"
    echo -e "  • Run 'nix-store --verify --check-contents' to check store integrity"
    echo -e "  • Consider 'nix-collect-garbage --delete-older-than 30d' for auto-cleanup"
    echo -e "  • Review /nix/var/nix/profiles for unused profiles"
    echo
    
    # Send desktop notification if available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Nix Cleanup Complete" "Reclaimed $saved_human (${percentage_saved}%)" -t 5000
    fi
    
    log_message "SUCCESS" "Cleanup completed. Reclaimed $saved_human (${percentage_saved}%)"
    
    if [[ "$dry_run" == "true" ]]; then
        return $EXIT_DRY_RUN
    fi
    
    return $EXIT_SUCCESS
}

#-------------------------------------------------------------------------------
# SECTION 7: MAIN EXECUTION
#-------------------------------------------------------------------------------

# Only run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    NIXempty "$@"
    exit $?
fi
