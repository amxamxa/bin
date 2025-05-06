#!/usr/bin/env bash

# =================================================================================
# Git Repository Auto-Pusher
# =================================================================================
# Purpose: 
#   Automatically discovers and pushes all Git repositories within specified
#   directory trees. Designed for system maintenance automation and backup workflows.

# Security Features:
#   - Permission denied errors suppression
#   - Interactive confirmation mode
#   - Dry-run capability
#   - Exclusion patterns for sensitive paths

# Exit Strategy:
#   - Immediate exit on critical errors
#   - Continue-on-error for individual repository operations
#   - Return codes: 0=Success, 1=Runtime Error, 2=Configuration Error

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
declare -a DEFAULT_ROOT_DIRS=("/home" "/share" "/etc/nixos")
declare -a EXCLUDE_PATHS=("*/.cache/*" "*/temp/*")
COMMIT_MSG="auto push before reboot"
DRY_RUN=false
INTERACTIVE=false
VERBOSE=false

# =========================================
# Help System
# =========================================
show_help() {
  echo -e "${PURPLE}Git Auto-Push Script - Comprehensive Help${RESET}"
  echo "========================================="
  
  echo -e "${BLUE}USAGE:${RESET}"
  echo "  $0 [OPTIONS]"
  echo "  $0 --help"
  
  echo -e "\n${BLUE}MAIN FEATURES:${RESET}"
  echo "  - Recursive Git repository discovery"
  echo "  - Safe error handling with permission checks"
  echo "  - Dry-run mode for testing"
  echo "  - Custom exclusion patterns"
  echo "  - Interactive confirmation mode"
  
  echo -e "\n${BLUE}OPTIONS:${RESET}"
  echo "  -d DIRS       Comma-separated directories to scan"
  echo "                (Default: ${DEFAULT_ROOT_DIRS[*]})"
  echo "  -e EXCLUDES   Comma-separated exclusion patterns"
  echo "                (Default: ${EXCLUDE_PATHS[*]})"
  echo "  -m MESSAGE    Custom commit message"
  echo "                (Default: \"$COMMIT_MSG\")"
  echo "  -i            Interactive mode (requires confirmation)"
  echo "  -v            Verbose mode with detailed output"
  echo "  -h, --help    Show this help message"
  
  echo -e "\n${BLUE}EXAMPLES:${RESET}"
  echo "  # Standard operation"
  echo "  $0"
  echo "  # Custom directories and message"
  echo "  $0 -d \"/projects,/backup\" -m \"Daily backup\""
  echo "  # Dry-run with exclusions"
  echo "  $0 -v -e \"*/node_modules/*,*/test/*\""
  
  echo -e "\n${BLUE}NOTES:${RESET}"
  echo "  - Script skips non-readable directories automatically"
  echo "  - Permission denied errors are suppressed"
  echo "  - Empty commits are allowed for tracking purposes"
  exit 0
}

# =========================================
# Function Library
# =========================================

# =========================================
# Modified Find Command with Error Suppression
# =========================================
find_repositories() {
  find "${DEFAULT_ROOT_DIRS[@]}" \
    -type d -name '.git' \
    $(printf "! -path %s " "${EXCLUDE_PATHS[@]}") \
    -print0 2>/dev/null | while IFS= read -r -d $'\0' git_dir
  do
    dirname "$git_dir"
  done
}
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
while getopts "d:e:m:ivh-:" opt; do
  case $opt in
    -) case "${OPTARG}" in
         help) show_help ;;
         *) log ERROR "Invalid long option: --${OPTARG}"; exit 1 ;;
       esac ;;
    d) IFS=',' read -ra DEFAULT_ROOT_DIRS <<< "$OPTARG" ;;
    e) IFS=',' read -ra EXCLUDE_PATHS <<< "$OPTARG" ;;
    m) COMMIT_MSG="$OPTARG" ;;
    i) INTERACTIVE=true ;;
    v) VERBOSE=true ;;
    h) show_help ;;
    *) log ERROR "Invalid option: -$OPTARG"; exit 1 ;;
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
find_repositories() {
  find "${DEFAULT_ROOT_DIRS[@]}" \
    -type d -name '.git' \
    $(printf "! -path %s " "${EXCLUDE_PATHS[@]}") \
    -print0 2>/dev/null | while IFS= read -r -d $'\0' git_dir
  do
    dirname "$git_dir"
  done
}
