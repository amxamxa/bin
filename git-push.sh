#!/usr/bin/env bash

# =============================================================================
# Git Auto-Push Script with Enhanced Configuration and Safety Features
# =============================================================================
# This script traverses specified directories to find Git repositories and
# performs automated push operations. Designed for system maintenance tasks
# like pre-reboot automation. Features colorized UI, dry-run mode, exclusion
# patterns, and interactive confirmation.

# =========================================
# Environment Configuration
# =========================================
# Color definitions (only when output is to terminal)
if [[ -t 1 ]]; then
  RESET="\e[0m"
  VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"
  GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"
  RED="\033[38;2;240;138;100m\033[48;2;147;18;61m"
  BLUE="\033[38;2;100;149;237m"
  PURPLE="\033[38;2;85;85;255m\033[48;2;21;16;46m"
else
  RESET="" VIOLET="" GREEN="" RED="" BLUE="" PURPLE=""
fi

# =========================================
# Configurable Parameters
# =========================================
# Default settings (override with environment variables or command-line args)
declare -a DEFAULT_ROOT_DIRS=("/home/project" "/home/amxamxa" "/share" "/etc/nixos")
declare -a EXCLUDE_PATHS=("*/.cache/*" "*/temp/*")  # Glob patterns to exclude
COMMIT_MSG="auto push before reboot"
DRY_RUN=false
INTERACTIVE=false
VERBOSE=false

# =========================================
# Function Library
# =========================================

# Display colored message with timestamp
log() {
  local level="$1" color=""
  shift
  case "$level" in
    SUCCESS) color="$GREEN" ;;
    ERROR) color="$RED" ;;
    INFO) color="$BLUE" ;;
    PROMPT) color="$PURPLE" ;;
    *) color="$VIOLET" ;;
  esac
  echo -e "${color}[$(date '+%T')] $*${RESET}"
}

# Validate if directory contains valid Git repository
is_valid_git_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null
}

# Main repository processing function
process_repository() {
  local repo_path="$1"
  log INFO "Processing repository: ${repo_path}"
  
  cd "${repo_path}" || { log ERROR "Failed to enter directory"; return 1; }

  if ! is_valid_git_repo; then
    log ERROR "Not a valid Git repository: ${repo_path}"
    return 2
  fi

  # Git operations with error checking
  execute_git_operation "add" "git add ."
  execute_git_operation "commit" "git commit -m \"${COMMIT_MSG}\" --allow-empty"
  execute_git_operation "push" "git push"
}

# Execute Git command with error handling and dry-run support
execute_git_operation() {
  local operation="$1" cmd="$2"
  
  log INFO "Attempting git ${operation}"
  if $DRY_RUN; then
    log INFO "[DRY-RUN] Would execute: ${cmd}"
    return 0
  fi

  if eval "${cmd}"; then
    log SUCCESS "Git ${operation} completed"
  else
    log ERROR "Git ${operation} failed (Code: $?)"
    return $?
  fi
}

# =========================================
# Main Script Execution
# =========================================
# Parse command-line options
while getopts "d:e:m:ivh" opt; do
  case $opt in
    d) IFS=',' read -ra DEFAULT_ROOT_DIRS <<< "$OPTARG";;
    e) IFS=',' read -ra EXCLUDE_PATHS <<< "$OPTARG";;
    m) COMMIT_MSG="$OPTARG";;
    i) INTERACTIVE=true;;
    v) VERBOSE=true;;
    h) echo "Usage: $0 [-d dirs] [-e excludes] [-m message] [-i] [-v] [-h]"; exit 0;;
    *) log ERROR "Invalid option: -$OPTARG"; exit 1;;
  esac
done

# Security confirmation in interactive mode
if $INTERACTIVE; then
  log PROMPT "Interactive mode enabled. Continue with processing? (y/N)"
  read -rn1 response
  [[ "${response,,}" != "y" ]] && exit 0
fi

# Repository discovery and processing
log INFO "Starting repository scan..."
find "${DEFAULT_ROOT_DIRS[@]}" \
  -type d -name '.git' \
  $(printf "! -path %s " "${EXCLUDE_PATHS[@]}") \
  -print0 | while IFS= read -r -d $'\0' git_dir; do

  repo_dir=$(dirname "$git_dir")
  process_repository "$repo_dir"
done

log SUCCESS "All repositories processed"
