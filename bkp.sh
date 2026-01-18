#!/usr/bin/env bash
####################################################
# Function: BKP (Backup with Enhanced Error Reporting)
# Purpose: Create timestamped backups with detailed error analysis
# Enhanced version with comprehensive debugging
# Usage: BKP <source> [source2 ... sourceN]
#
# Features:
#   - Timestamped backups (format: YYMMDD_filename)
#   - Multiple source handling
#   - Detailed error reporting with specific diagnosis
#   - Preserves all file attributes (permissions, timestamps, ownership)
#   - Handles both files and directories
#   - Skips symbolic links to prevent issues
#   - Cross-filesystem awareness
#
# Exit Codes:
#   0 - All operations successful or at least one success
#   1 - No sources provided or all operations failed
################################################################################

# ANSI Color definitions using $'...' syntax for proper escape sequence handling
# This syntax interprets \033 correctly, unlike double-quoted strings with \\033
# Format: \033[38;2;R;G;Bm (foreground) \033[48;2;R;G;Bm (background)
readonly RASP=$'\033[38;2;32;0;21m\033[48;2;163;64;217m'
readonly PINK=$'\033[38;2;255;105;180m\033[48;2;75;0;130m'
readonly FUCHSIA=$'\033[38;2;239;217;129m\033[48;2;59;14;122m'
readonly VIOLET=$'\033[38;2;255;0;53m\033[48;2;34;0;82m'
readonly BROWN=$'\033[38;2;239;217;129m\033[48;2;210;105;30m'
readonly LEMON=$'\033[38;2;216;101;39m\033[48;2;218;165;32m'
readonly RESET=$'\033[0m'

BKP() {
    ############################################################################
    # Main backup function
    # Processes each source argument and creates timestamped backup copies
    ############################################################################
    
    # Validate input: at least one source must be provided
    if [[ $# -eq 0 ]]; then
        printf "%s BKP: Error: No source specified. Usage: BKP <source> [source2 ... sourceN] %s\n" \
            "$VIOLET" "$RESET" >&2
        return 1
    fi

    # Generate timestamp for this backup session (format: YYMMDD)
    # All backups in this invocation share the same timestamp
    local timestamp
    timestamp=$(date +"%y%m%d")

    # Counters for operation tracking
    local success_count=0
    local failure_count=0

    # Setup cleanup trap for temporary files
    # This ensures error_log files are removed even if function exits early
    local error_log
    error_log=$(mktemp) || {
        printf "%s BKP: Error: Failed to create temporary file %s\n" \
            "$VIOLET" "$RESET" >&2
        return 1
    }
    trap 'rm -f "$error_log"' RETURN

    ############################################################################
    # Process each source argument
    ############################################################################
    for source in "$@"; do
        # Validation: Check if source exists
        if [[ ! -e "$source" ]]; then
            printf "%s BKP: Error: Source '%s' does not exist. %s\n" \
                "$VIOLET" "$source" "$RESET" >&2
            ((failure_count++))
            continue
        fi

        # Skip symbolic links: Prevents issues with circular references
        # and ensures we backup actual content, not just links
        if [[ -L "$source" ]]; then
            printf "%s BKP: Info: Skipping symbolic link '%s'. %s\n" \
                "$BROWN" "$source" "$RESET" >&2
            continue
        fi

        ########################################################################
        # Construct backup path
        ########################################################################
        local basename parent_dir backup_name backup_path
        
        # Extract filename/directory name from path
        basename=$(basename -- "$source")
        
        # Get parent directory for backup placement
        # Backup is created in same directory as source
        parent_dir=$(dirname -- "$source")
        
        # Construct backup name: YYMMDD_originalname
        backup_name="${timestamp}_${basename}"
        backup_path="${parent_dir}/${backup_name}"

        # Check if backup already exists to prevent overwriting
        # This can happen if BKP is called multiple times on same day
        if [[ -e "$backup_path" ]]; then
            printf "%s BKP: Error: Backup '%s' already exists. %s\n" \
                "$VIOLET" "$backup_name" "$RESET" >&2
            ((failure_count++))
            continue
        fi

        ########################################################################
        # Perform backup operation based on source type
        ########################################################################
        if [[ -f "$source" ]]; then
            # Handle regular files
            printf "%s BKP: Copying file '%s' to '%s'... %s\n" \
                "$LEMON" "$source" "$backup_name" "$RESET"
            
            # cp options explained:
            # --verbose: Show files being copied (output to stdout)
            # --no-dereference: Don't follow symlinks in source
            # --preserve=all: Keep mode, ownership, timestamps, context, links, xattr
            # --: Separator between options and arguments (prevents issues with filenames starting with -)
            if ! cp --verbose --no-dereference --preserve=all -- \
                "$source" "$backup_path" 2>"$error_log"; then
                
                local error_details
                error_details=$(cat "$error_log")
                _analyze_cp_error "$source" "$error_details"
                ((failure_count++))
                continue
            fi
            ((success_count++))
            
        elif [[ -d "$source" ]]; then
            # Handle directories
            printf "%s BKP: Copying directory '%s' to '%s'... %s\n" \
                "$LEMON" "$source" "$backup_name" "$RESET"
            
            # Additional options for directory copying:
            # --recursive: Copy directories recursively
            # --one-file-system: Don't cross filesystem boundaries
            #   This prevents accidentally copying mounted filesystems like /proc, /sys
            if ! cp --verbose --no-dereference --recursive --preserve=all \
                --one-file-system -- "$source" "$backup_path" 2>"$error_log"; then
                
                local error_details
                error_details=$(cat "$error_log")
                _analyze_cp_error "$source" "$error_details"
                ((failure_count++))
                continue
            fi
            ((success_count++))
            
        else
            # Handle special files (devices, sockets, etc.)
            printf "%s BKP: Error: '%s' is neither a file nor a directory. %s\n" \
                "$VIOLET" "$source" "$RESET" >&2
            ((failure_count++))
            continue
        fi
    done

    ############################################################################
    # Return appropriate exit code based on results
    ############################################################################
    if [[ $failure_count -gt 0 && $success_count -eq 0 ]]; then
        # All operations failed
        return 1
    fi
    
    # At least one operation succeeded, or no operations were attempted
    return 0
}

################################################################################
# Helper function: Analyze cp error messages and provide user-friendly output
# Arguments:
#   $1 - source path that failed
#   $2 - error details from stderr
################################################################################
_analyze_cp_error() {
    local source="$1"
    local error_details="$2"
    local error_message

    # Pattern matching against common cp error messages
    # Each case provides a specific, actionable error message
    case "$error_details" in
        *"Permission denied"*)
            error_message="Permission denied. Check if you have write access to the target directory or read access to the source."
            ;;
        *"No space left on device"*)
            error_message="No space left on device. Free up disk space and try again."
            ;;
        *"Cross-device link"*)
            error_message="Cross-device link detected. Source and target are on different filesystems. Use rsync or adjust --one-file-system behavior."
            ;;
        *"File exists"*)
            error_message="Target file or directory already exists. Remove it or choose a different backup name."
            ;;
        *"Input/output error"*)
            error_message="Input/output error. Check disk health with smartctl or dmesg. Hardware issue possible."
            ;;
        *"Operation not permitted"*)
            error_message="Operation not permitted. Check filesystem permissions, SELinux context, or file attributes (lsattr/chattr)."
            ;;
        *"Directory not empty"*)
            error_message="Directory not empty. Cannot overwrite non-empty directory."
            ;;
        *"Read-only file system"*)
            error_message="Read-only file system. Target filesystem is mounted read-only. Remount with write access."
            ;;
        *"Too many levels of symbolic links"*)
            error_message="Too many levels of symbolic links. Circular symlink reference detected."
            ;;
        *"Interrupted system call"*)
            error_message="Interrupted system call. Operation was interrupted. Retry the backup."
            ;;
        *)
            # Catch-all for unknown errors - display raw error for debugging
            error_message="Unknown error: $error_details"
            ;;
    esac

    printf "%s BKP: Error: Failed to copy '%s'. Reason: %s %s\n" \
        "$VIOLET" "$source" "$error_message" "$RESET" >&2
}

################################################################################
# Diagnostic function: Test if BKP is properly loaded and functional
# Usage: _test_bkp_functionality
################################################################################
_test_bkp_functionality() {
    echo "=== BKP Diagnostic Test ==="   
    # Test 1: Color output
    echo "Test 1: Color codes"
    printf "%s COLOR TEST %s\n" "$VIOLET" "$RESET"
    # Test 2: Function is defined
    echo "Test 2: Function defined"
    type BKP
    # Test 3: Create test file and backup
    echo "Test 3: Basic functionality"
    local testfile="/tmp/bkp_test_$$"
    echo "test content" > "$testfile"
    BKP "$testfile"
    ls -la /tmp/bkp_test_* 2>/dev/null || echo "No backup created!"
    rm -f /tmp/bkp_test_* 2>/dev/null   
    echo "=== Diagnostic Complete ==="
}

