#!/usr/bin/env bash
# =============================================================================
# Script Name : set-permissions.sh
# Description : Recursively set file/directory permissions
#               Files       → 644  (rw-r--r--)
#               Directories → 755  (rwxr-xr-x)
# Usage       : ./set-permissions.sh [OPTIONS] <path> [<path2> ...]
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# --- Constants ---------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly FILE_PERM="644"   # rw-r--r--
readonly DIR_PERM="755"    # rwxr-xr-x

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- Counters ----------------------------------------------------------------
COUNT_FILES=0
COUNT_DIRS=0
COUNT_SKIP=0
COUNT_ERR=0

# --- Defaults ----------------------------------------------------------------
DRY_RUN=false
VERBOSE=false
RECURSIVE=true

# --- Logging -----------------------------------------------------------------
log()     { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
verbose() { $VERBOSE && printf "${BLUE}[DBG]${NC}   %s\n" "$*" || true; }

# --- Usage -------------------------------------------------------------------
usage() {
    cat <<EOF

Usage: $SCRIPT_NAME [OPTIONS] <path> [<path2> ...]

  Set permissions recursively:
    Files       →  $FILE_PERM  (rw-r--r--)
    Directories →  $DIR_PERM  (rwxr-xr-x)

Options:
  -h, --help        Show this help
  -v, --verbose     Show every chmod operation
  -d, --dry-run     Simulate — print what would change, apply nothing
  -n, --no-recurse  Only process the given path(s), not subdirectories

Examples:
  $SCRIPT_NAME /share/zsh
  $SCRIPT_NAME --dry-run /home/user/project
  $SCRIPT_NAME -v -n /etc/myapp

EOF
}

# --- Argument Parsing --------------------------------------------------------
parse_args() {
    local -a targets=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)        usage; exit 0 ;;
            -v|--verbose)     VERBOSE=true ;;
            -d|--dry-run)     DRY_RUN=true ;;
            -n|--no-recurse)  RECURSIVE=false ;;
            -*)               error "Unknown option: $1"; usage; exit 1 ;;
            *)                targets+=("$1") ;;
        esac
        shift
    done

    # Return targets via global (bash <4.3 nameref workaround)
    TARGET_PATHS=("${targets[@]:-}")
}

# --- Sanity Checks -----------------------------------------------------------
check_deps() {
    local deps=(chmod find)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            error "Required tool not found: $dep"
            exit 1
        fi
    done
}

validate_targets() {
    for t in "${TARGET_PATHS[@]}"; do
        if [[ ! -e "$t" ]]; then
            error "Path does not exist: $t"
            exit 1
        fi
        if [[ ! -r "$t" ]]; then
            error "Path not readable (check permissions): $t"
            exit 1
        fi
    done
}

# --- Core: apply chmod -------------------------------------------------------
# Arguments: path, desired_perm, type ("file"|"dir"), current_perm
apply_chmod() {
    local path="$1" perm="$2" type="$3" current="$4"

    if [[ "$current" == "$perm" ]]; then
        verbose "SKIP  [$type] ($current) $path"
        (( COUNT_SKIP++ )) || true
        return 0
    fi

    verbose "CHMOD [$type] $current → $perm  $path"

    if $DRY_RUN; then
        printf "  ${YELLOW}[dry-run]${NC} chmod %s  %s  (was %s)\n" "$perm" "$path" "$current"
    else
        if chmod "$perm" "$path" 2>/dev/null; then
            if $VERBOSE; then
                log "chmod $perm  $path  (was $current)"
            fi
        else
            error "chmod failed: $path"
            (( COUNT_ERR++ )) || true
            return 1
        fi
    fi

    # Increment counters only for changed (or would-be changed) items
    if [[ "$type" == "file" ]]; then (( COUNT_FILES++ )) || true; fi
    if [[ "$type" == "dir"  ]]; then (( COUNT_DIRS++  )) || true; fi
}

# --- Core: process a single root path ----------------------------------------
process_path() {
    local root="$1"
    info "Processing: $root"

    if $RECURSIVE; then
        # Process directories first (top-down)
        while IFS= read -r -d '' cur_perm && IFS= read -r -d '' dir; do
            apply_chmod "$dir" "$DIR_PERM" "dir" "$cur_perm"
        done < <(find "$root" -type d -printf '%m\0%p\0')

        # Then files
        while IFS= read -r -d '' cur_perm && IFS= read -r -d '' file; do
            apply_chmod "$file" "$FILE_PERM" "file" "$cur_perm"
        done < <(find "$root" -type f -printf '%m\0%p\0')

    else
        # Non-recursive: only the given path itself
        local cur_perm
        if [[ -d "$root" ]]; then
            cur_perm=$(find "$root" -maxdepth 0 -printf '%m')
            apply_chmod "$root" "$DIR_PERM" "dir" "$cur_perm"
        elif [[ -f "$root" ]]; then
            cur_perm=$(find "$root" -maxdepth 0 -printf '%m')
            apply_chmod "$root" "$FILE_PERM" "file" "$cur_perm"
        fi
    fi
}

# --- Summary -----------------------------------------------------------------
print_summary() {
    local label="Applied"
    $DRY_RUN && label="Would apply"

    printf "\n%s\n" "────────────────────────────────────────"
    printf "  %-22s %s\n" "Mode:" "$( $DRY_RUN && echo 'dry-run' || echo 'live' )"
    printf "  %-22s %s\n" "Recursive:" "$RECURSIVE"
    printf "  %-22s ${GREEN}%d${NC}\n"    "$label (files):"  "$COUNT_FILES"
    printf "  %-22s ${GREEN}%d${NC}\n"    "$label (dirs):"   "$COUNT_DIRS"
    printf "  %-22s ${BLUE}%d${NC}\n"     "Skipped (ok):"    "$COUNT_SKIP"
    printf "  %-22s ${RED}%d${NC}\n"      "Errors:"          "$COUNT_ERR"
    printf "%s\n\n" "────────────────────────────────────────"

    (( COUNT_ERR > 0 )) && return 1 || return 0
}

# --- Main --------------------------------------------------------------------
declare -a TARGET_PATHS

main() {
    parse_args "$@"

    if [[ ${#TARGET_PATHS[@]} -eq 0 ]]; then
        error "No target path given."
        usage
        exit 1
    fi

    check_deps
    validate_targets

    $DRY_RUN && warn "DRY-RUN mode — no changes will be applied"

    for target in "${TARGET_PATHS[@]}"; do
        process_path "$target"
    done

    print_summary
}

main "$@"
