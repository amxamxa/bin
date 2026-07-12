#!/usr/bin/env bash
################################################################################
# Script: bkp-to-desti.sh  (Backup with Rsync & Enhanced Error Reporting)
# Purpose: Rsync-based backups of mount points / directories to a destination
#
# Usage:
#   bkp-to-desti.sh -S <source1> [source2 ... sourceN] -D <destination>
#
# Example:
#   sudo ./bkp-to-desti.sh -S / /home/project /public -D /run/media/amxamxa/wd-320
#   sudo ./bkp-to-desti.sh -S /mnt/sdb5 -D /run/media/amxamxa/wd-320
#
# Options:
#   -S  One or more source paths (mount points or directories)
#   -D  Destination base directory (single path, must already exist)
#
# Features:
#   - Timestamped backup subdirectories (format: YYMMDD_<basename>)
#   - Multiple source handling via -S flag
#   - Detailed rsync exit-code analysis with actionable messages
#   - Preserves all file attributes (-aAXH: acl, xattr, hardlinks)
#   - Does NOT cross filesystem boundaries (--one-file-system)
#   - Skips top-level symbolic links to prevent circular issues
#   - Progress display (--info=progress2) + stats summary
#   - Dry-run mode: BKPR_DRY_RUN=1 ./bkp-to-desti.sh ...
#
# Exit Codes:
#   0 - All operations successful (or at least one succeeded)
#   1 - Argument error / destination missing / all operations failed
#
# rsync Exit Codes handled:
#   1  Syntax/usage error          12 Protocol data stream error
#   2  Protocol incompatibility    20 SIGINT / SIGUSR1 received
#   3  File selection error        23 Partial transfer (errors)
#   4  Action not supported        24 Partial transfer (vanished files)
#   5  Protocol start error        30 Timeout send/receive
#   10 Socket I/O error
#   11 File I/O error
################################################################################

# ── ANSI Color definitions ────────────────────────────────────────────────────
# Uses $'...' syntax so \033 is interpreted correctly in all shells
 
 PINK=$'\033[38;2;255;105;180m\033[48;2;75;0;130m'
 FUCHSIA=$'\033[38;2;239;217;129m\033[48;2;59;14;122m'
 VIOLET=$'\033[38;2;255;0;53m\033[48;2;34;0;82m'
 BROWN=$'\033[38;2;239;217;129m\033[48;2;210;105;30m'
 LEMON=$'\033[38;2;216;101;39m\033[48;2;218;165;32m'
 RESET=$'\033[0m'

# ── Usage / help ──────────────────────────────────────────────────────────────
_usage() {
    printf "%s bkp-to-desti.sh %s\n\n" "$RASP" "$RESET"
    printf "Usage:\n"
    printf "  %s -S <source1> [source2 ... sourceN] -D <destination>%s\n\n" "$LEMON" "$RESET"
    printf "Options:\n"
    printf "  -S  One or more source paths (mount points or directories)\n"
    printf "  -D  Destination base directory (must already exist)\n\n"
    printf "Environment:\n"
    printf "  BKPR_DRY_RUN=1   Simulate backup without writing files\n\n"
    printf "Example:\n"
    printf "  sudo %s./bkp-to-desti.sh -S / /home/project /public -D /run/media/amxamxa/wd-320%s\n" \
        "$FUCHSIA" "$RESET"
}

# ── Argument parser ───────────────────────────────────────────────────────────
# getopts cannot handle multiple values per flag natively, so arguments are
# parsed manually. Strategy:
#   - Iterate all positional parameters
#   - '-S' activates source-collection mode; collect until '-D' is seen
#   - '-D' deactivates source-collection mode; next token becomes destination
#   - Any token starting with '-' that is not '-S'/'-D' is an unknown flag
_parse_args() {
    SOURCES=()          # array of source paths
    DESTINATION=""      # single destination path

    local mode=""       # current parsing mode: "S" | "D" | ""

    for arg in "$@"; do
        case "$arg" in
            -S)
                mode="S"
                ;;
            -D)
                mode="D"
                ;;
            -*)
                # Unknown flag – abort with usage hint
                printf "%s bkp-to-desti.sh: Unknown option '%s'. %s\n" \
                    "$VIOLET" "$arg" "$RESET" >&2
                _usage >&2
                exit 1
                ;;
            *)
                # Plain token: route to current mode
                case "$mode" in
                    S)  SOURCES+=("$arg") ;;
                    D)
                        # Only the first token after -D is used as destination;
                        # further tokens would indicate a second -S/-D section
                        if [[ -z "$DESTINATION" ]]; then
                            DESTINATION="$arg"
                        else
                            printf "%s bkp-to-desti.sh: Extra token '%s' after -D. Only one destination allowed. %s\n" \
                                "$VIOLET" "$arg" "$RESET" >&2
                            _usage >&2
                            exit 1
                        fi
                        ;;
                    "")
                        printf "%s bkp-to-desti.sh: Unexpected token '%s' before any flag. %s\n" \
                            "$VIOLET" "$arg" "$RESET" >&2
                        _usage >&2
                        exit 1
                        ;;
                esac
                ;;
        esac
    done

    # ── Validate parsed values ────────────────────────────────────────────────
    local has_error=0

    if [[ ${#SOURCES[@]} -eq 0 ]]; then
        printf "%s bkp-to-desti.sh: Error: No source(s) provided via -S. %s\n" \
            "$VIOLET" "$RESET" >&2
        has_error=1
    fi

    if [[ -z "$DESTINATION" ]]; then
        printf "%s bkp-to-desti.sh: Error: No destination provided via -D. %s\n" \
            "$VIOLET" "$RESET" >&2
        has_error=1
    fi

    if [[ $has_error -eq 1 ]]; then
        _usage >&2
        exit 1
    fi
}

# ── Helper: rsync exit-code analysis ─────────────────────────────────────────
################################################################################
# _analyze_rsync_error
# Arguments:
#   $1 - source path that failed
#   $2 - rsync exit code (integer)
#   $3 - stderr output captured from rsync
################################################################################
_analyze_rsync_error() {
    local source="$1"
    local exit_code="$2"
    local stderr_output="$3"
    local error_message

    # Map rsync exit codes to actionable human-readable messages
    case "$exit_code" in
        1)  error_message="Syntax or usage error. Check rsync arguments." ;;
        2)  error_message="Protocol incompatibility. rsync versions may differ." ;;
        3)  error_message="Error selecting input/output files. Check paths." ;;
        4)  error_message="Action not supported. Filesystem may lack ACL/xattr." ;;
        5)  error_message="Error starting client-server protocol." ;;
        10) error_message="Socket I/O error. Pipe or network connection problem." ;;
        11) error_message="File I/O error. Run: smartctl -a /dev/sdX  or  dmesg | tail" ;;
        12) error_message="rsync protocol data stream error. Possible data corruption." ;;
        20) error_message="Received SIGINT/SIGUSR1. Backup interrupted by user or system." ;;
        23) error_message="Partial transfer due to errors. Some files were NOT copied." ;;
        24) error_message="Partial transfer: source files vanished mid-transfer. Retry." ;;
        30) error_message="Timeout in data send/receive. Destination may be unresponsive." ;;
        *)  error_message="Unknown rsync exit code ${exit_code}. Raw: ${stderr_output}" ;;
    esac

    # Additional inline hints extracted from stderr text
    local inline_hint=""
    if   [[ "$stderr_output" == *"Permission denied"*     ]]; then
        inline_hint=" [Hint: run with sudo or fix directory permissions]"
    elif [[ "$stderr_output" == *"No space left"*         ]]; then
        inline_hint=" [Hint: destination is full – free space first]"
    elif [[ "$stderr_output" == *"Read-only file system"* ]]; then
        inline_hint=" [Hint: destination mounted read-only – check mount flags]"
    elif [[ "$stderr_output" == *"Operation not permitted"* ]]; then
        inline_hint=" [Hint: ACL/xattr unsupported on destination fs – try without -AX]"
    fi

    printf "%s bkp-to-desti.sh: Error: Failed '%s'. Code %d: %s%s %s\n" \
        "$VIOLET" "$source" "$exit_code" "$error_message" "$inline_hint" "$RESET" >&2
}

# ── Main backup logic ─────────────────────────────────────────────────────────
_run_backup() {
    # Validate destination directory
    if [[ ! -d "$DESTINATION" ]]; then
        printf "%s bkp-to-desti.sh: Error: Destination '%s' does not exist or is not a directory. %s\n" \
            "$VIOLET" "$DESTINATION" "$RESET" >&2
        return 1
    fi

    # Timestamp shared across all sources in this invocation (format: YYMMDD)
    local timestamp
    timestamp=$(date +"%y%m%d")

    # Dry-run support: export BKPR_DRY_RUN=1 to simulate without writing
    local dry_run_flag=""
    if [[ "${BKPR_DRY_RUN:-0}" == "1" ]]; then
        dry_run_flag="--dry-run"
        printf "%s bkp-to-desti.sh: DRY-RUN mode active – no files will be written. %s\n" \
            "$BROWN" "$RESET"
    fi

    # Operation counters
    local success_count=0
    local failure_count=0

    # Temporary file for capturing rsync stderr per source
    local error_log
    error_log=$(mktemp) || {
        printf "%s bkp-to-desti.sh: Error: Failed to create temporary file. %s\n" \
            "$VIOLET" "$RESET" >&2
        return 1
    }
    # Cleanup temp file on function return (any path)
    trap 'rm -f "$error_log"' RETURN

    ############################################################################
    # Process each source
    ############################################################################
    for source in "${SOURCES[@]}"; do

        # ── Existence check ───────────────────────────────────────────────────
        if [[ ! -e "$source" ]]; then
            printf "%s bkp-to-desti.sh: Error: Source '%s' does not exist. %s\n" \
                "$VIOLET" "$source" "$RESET" >&2
            ((failure_count++))
            continue
        fi

        # ── Skip top-level symbolic links ─────────────────────────────────────
        if [[ -L "$source" ]]; then
            printf "%s bkp-to-desti.sh: Info: Skipping top-level symbolic link '%s'. %s\n" \
                "$BROWN" "$source" "$RESET" >&2
            continue
        fi

        # ── Construct timestamped target directory ────────────────────────────
        # basename strips trailing slashes: '/public/' → 'public'
        local base_name target_dir
        base_name=$(basename -- "${source%/}")
        target_dir="${DESTINATION}/${timestamp}_${base_name}"

        # ── Guard: target must not already exist ──────────────────────────────
        if [[ -e "$target_dir" ]]; then
            printf "%s bkp-to-desti.sh: Error: Target '%s' already exists. Remove it or wait for tomorrow. %s\n" \
                "$VIOLET" "$target_dir" "$RESET" >&2
            ((failure_count++))
            continue
        fi

        mkdir -p "$target_dir" || {
            printf "%s bkp-to-desti.sh: Error: Cannot create target directory '%s'. %s\n" \
                "$VIOLET" "$target_dir" "$RESET" >&2
            ((failure_count++))
            continue
        }

        ########################################################################
        # rsync options:
        #   -a               Archive mode (recursive, preserve symlinks/perms/
        #                    timestamps/owner/group/special files)
        #   -A               Preserve ACLs
        #   -X               Preserve extended attributes (xattr)
        #   -H               Preserve hard links
        #   -v               Verbose: list transferred files
        #   --one-file-system  Do NOT cross mount points inside the source tree
        #   --info=progress2   Single-line overall progress indicator
        #   --stats            Print transfer statistics at end
        #   --exclude=...      Drop virtual/pseudo filesystems (root only)
        #   --                 Option terminator: protects paths starting with '-'
        #
        # Trailing slash on source ("${source%/}/"):
        #   Copies the *contents* of the directory, not the directory itself.
        #   Without it rsync would nest: target_dir/basename/files
        #   With it:                     target_dir/files          ← correct
        ########################################################################

        # Extra excludes are added only when backing up the root filesystem
        local extra_excludes=()
        if [[ "$source" == "/" || "$source" == "/." ]]; then
            extra_excludes=(
                "--exclude=/proc/*"
                "--exclude=/sys/*"
                "--exclude=/dev/*"
                "--exclude=/run/*"
                "--exclude=/tmp/*"
                "--exclude=/home/video*"
                "--exclude=/home/project/iso/*"
                "--exclude=/mnt/*"
                "--exclude=/lost+found"
            )
        fi

        printf "%s bkp-to-desti.sh: Starting backup: '%s'  →  '%s' %s\n" \
            "$LEMON" "$source" "$target_dir" "$RESET"

        rsync -aAXHv \
            --one-file-system \
            --info=progress2 \
            --stats \
            "${extra_excludes[@]}" \
            $dry_run_flag \
            -- \
            "${source%/}/" \
            "$target_dir/" \
            2>"$error_log"

        local rsync_exit=$?

        if [[ $rsync_exit -ne 0 ]]; then
            local stderr_content
            stderr_content=$(cat "$error_log")
            _analyze_rsync_error "$source" "$rsync_exit" "$stderr_content"
            ((failure_count++))
            continue
        fi

        printf "%s bkp-to-desti.sh: OK: '%s'  →  '%s' %s\n" \
            "$FUCHSIA" "$source" "$target_dir" "$RESET"
        ((success_count++))

    done

    ############################################################################
    # Summary report
    ############################################################################
    printf "%s bkp-to-desti.sh: Summary – succeeded: %d  failed: %d %s\n" \
        "$RASP" "$success_count" "$failure_count" "$RESET"

    ############################################################################
    # Return appropriate exit code
    #   0 – at least one operation succeeded
    #   1 – all operations failed / nothing done
    ############################################################################
    if [[ $failure_count -gt 0 && $success_count -eq 0 ]]; then
        return 1
    fi
    return 0
}

# ── Diagnostic function ───────────────────────────────────────────────────────
################################################################################
# _test_bkp_functionality
# Verifies colors, function definitions, rsync availability, and a live dry-run
# Usage: bash -c "source bkp-to-desti.sh && _test_bkp_functionality"ity
# 
################################################################################
_test_bkp_functionality() {
    echo "=== bkp-to-desti.sh Diagnostic Test ==="

    # Test 1: Color output
    echo ""
    echo "Test 1: Color codes"
    printf "%s VIOLET  %s\n" "$VIOLET"  "$RESET"
    printf "%s LEMON   %s\n" "$LEMON"   "$RESET"
    printf "%s FUCHSIA %s\n" "$FUCHSIA" "$RESET"
    printf "%s BROWN   %s\n" "$BROWN"   "$RESET"
    printf "%s RASP    %s\n" "$RASP"    "$RESET"
    printf "%s PINK    %s\n" "$PINK"    "$RESET"

    # Test 2: Core functions are defined
    echo ""
    echo "Test 2: Functions defined"
    for fn in _parse_args _analyze_rsync_error _run_backup _test_bkp_functionality; do
        if declare -f "$fn" &>/dev/null; then
            printf "  %s✔ %s%s\n" "$FUCHSIA" "$fn" "$RESET"
        else
            printf "  %s✘ %s (MISSING)%s\n" "$VIOLET" "$fn" "$RESET"
        fi
    done

    # Test 3: rsync is available in PATH
    echo ""
    echo "Test 3: rsync availability"
    if command -v rsync &>/dev/null; then
        printf "  %s✔ %s%s\n" "$FUCHSIA" "$(rsync --version | head -1)" "$RESET"
    else
        printf "  %s✘ rsync not found. Install: nix-env -iA nixos.rsync %s\n" \
            "$VIOLET" "$RESET"
    fi

    # Test 4: Dry-run with valid source and destination
    echo ""
    echo "Test 4: Dry-run backup /tmp/bkp_src → /tmp/bkp_dst"
    local src_dir dst_dir
    src_dir=$(mktemp -d /tmp/bkp_src_XXXXXX)
    dst_dir=$(mktemp -d /tmp/bkp_dst_XXXXXX)
    echo "hello backup" > "${src_dir}/sample.txt"

    SOURCES=("$src_dir")
    DESTINATION="$dst_dir"
    BKPR_DRY_RUN=1 _run_backup
    printf "  → exit code: %d\n" "$?"
    rm -rf "$src_dir" "$dst_dir"

    # Test 5: Error path – non-existent source
    echo ""
    echo "Test 5: Non-existent source (graceful error expected)"
    local fake_dst
    fake_dst=$(mktemp -d /tmp/bkp_dst_XXXXXX)
    SOURCES=("/this/does/not/exist")
    DESTINATION="$fake_dst"
    _run_backup
    printf "  → exit code: %d\n" "$?"
    rm -rf "$fake_dst"

    # Test 6: Argument parser
    echo ""
    echo "Test 6: Argument parser (-S / -D)"
    _parse_args -S /foo /bar /baz -D /mnt/target
    printf "  SOURCES     : %s\n" "${SOURCES[*]}"
    printf "  DESTINATION : %s\n" "$DESTINATION"

    echo ""
    echo "=== Diagnostic Complete ==="
}

# ── Entry point ───────────────────────────────────────────────────────────────
# Script is runnable directly OR sourceable for the diagnostic function.
# When sourced, $BASH_SOURCE[0] != $0, so _run_backup is not called.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    _parse_args "$@"
    _run_backup
fi
