#!/usr/bin/env bash
#
# NIXwo.sh - NixOS Binary Inspector
# 
# Description:
#   Analyzes binaries and shell commands on NixOS systems.
#   For Nix store binaries: shows store path, derivation, dependencies, and metadata.
#   For shell builtins/functions/aliases: shows type, definition, and source location.
#
# Usage:
#   NIXwo.sh <command-name>
#
# Examples:
#   NIXwo.sh ls          # Nix store binary analysis
#   NIXwo.sh firefox     # Nix store binary analysis
#   NIXwo.sh cd          # Shell builtin analysis
#   NIXwo.sh ll          # Alias analysis (if defined)
#
# Requirements:
#   - NixOS system
#   - nix-store command available
#   - Predefined color variables in shell environment:
#     PINK, PINK2, RESET, SKY, RED, IVORY, BOLD, BROWN, AMBER, VIO
#
# Author: IT-Engineer
# Version: 2.1
# Last Modified: 2026-02-14
#

set -euo pipefail  # Exit on errors, undefined variables, pipe failures

# ============================================================================
# FUNCTION DEFINITIONS
# ============================================================================

# --- Function: Analyze shell builtins, functions, and aliases ---
analyze_shell_command() {
    local cmd="$1"
    
    echo -e "${BOLD}━━━ Shell Command Analysis ━━━${RESET}"
    echo -e "${VIO}This is NOT a Nix store binary${RESET}"
    echo
    
    # Determine command type
    local cmd_type=""
    local definition=""
    local source_file=""
    
    # Check what type it is (works in both bash and zsh)
    if type -t "$cmd" >/dev/null 2>&1; then
        # bash
        cmd_type="$(type -t "$cmd" 2>/dev/null)"
    elif whence -w "$cmd" >/dev/null 2>&1; then
        # zsh
        cmd_type="$(whence -w "$cmd" 2>/dev/null | cut -d: -f2 | tr -d ' ')"
    fi
    
    case "$cmd_type" in
        builtin)
            echo -e "${SKY}➤ Type:${RESET} ${BOLD}Shell Builtin${RESET}"
            echo -e "${IVORY}  Built into the shell binary itself${RESET}"
            
            # Try to find shell binary
            if [ -n "$SHELL" ]; then
                shell_path="$(readlink -f "$SHELL" 2>/dev/null || echo "$SHELL")"
                echo -e "${IVORY}  Shell binary:${RESET} ${shell_path}"
                
                # Check if it's from Nix
                if echo "$shell_path" | grep -q '^/nix/store/'; then
                    store_path="$(echo "$shell_path" | grep -o '^/nix/store/[^/]*')"
                    echo -e "${IVORY}  Nix package:${RESET} ${store_path}"
                fi
            fi
            
            # Show help if available
            echo
            echo -e "${SKY}➤ Quick Help:${RESET}"
            if command -v man >/dev/null 2>&1; then
                echo -e "${IVORY}  Run:${RESET} ${BOLD}man zshbuiltins${RESET} or ${BOLD}man bash${RESET}"
            fi
            ;;
            
        function)
            echo -e "${SKY}➤ Type:${RESET} ${BOLD}Shell Function${RESET}"
            echo
            
            # Get function definition
            if declare -f "$cmd" >/dev/null 2>&1; then
                # bash
                definition="$(declare -f "$cmd" 2>/dev/null)"
            elif functions "$cmd" >/dev/null 2>&1; then
                # zsh
                definition="$(functions "$cmd" 2>/dev/null)"
            fi
            
            # Show definition (first 10 lines)
            if [ -n "$definition" ]; then
                echo -e "${SKY}➤ Definition (first 10 lines):${RESET}"
                echo -e "${BROWN}${definition}${RESET}" | head -n 10
                
                line_count="$(echo "$definition" | wc -l)"
                if [ "$line_count" -gt 10 ]; then
                    echo -e "${IVORY}  ... (${line_count} lines total)${RESET}"
                fi
            fi
            
            # Try to find source file
            echo
            echo -e "${SKY}➤ Possible Source Locations:${RESET}"
            search_function_source "$cmd"
            ;;
            
        alias)
            echo -e "${SKY}➤ Type:${RESET} ${BOLD}Shell Alias${RESET}"
            echo
            
            # Get alias definition
            if alias "$cmd" >/dev/null 2>&1; then
                definition="$(alias "$cmd" 2>/dev/null)"
                echo -e "${SKY}➤ Definition:${RESET}"
                echo -e "${BROWN}  ${definition}${RESET}"
            fi
            
            # Try to find source file
            echo
            echo -e "${SKY}➤ Possible Source Locations:${RESET}"
            search_alias_source "$cmd"
            ;;
            
        *)
            echo -e "${AMBER}⚠ Unknown command type${RESET}"
            echo -e "${SKY}  Command: ${cmd}${RESET}"
            ;;
    esac
    
    echo
    echo -e "${PINK2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

# --- Function: Search for function definition in config files ---
search_function_source() {
    local func_name="$1"
    local found=false
    
    # Common zsh config locations
    local config_files=(
        "$HOME/.zshrc"
        "$HOME/.zshenv"
        "$HOME/.zprofile"
        "$HOME/.zlogin"
        "$HOME/.config/zsh/.zshrc"
        "$HOME/.zsh/functions/$func_name"
    )
    
    # Also check if ZDOTDIR is set
    if [ -n "${ZDOTDIR:-}" ]; then
        config_files+=("$ZDOTDIR/.zshrc")
        config_files+=("$ZDOTDIR/.zshenv")
    fi
    
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            if grep -q "^[[:space:]]*${func_name}[[:space:]]*()[[:space:]]*{" "$config" 2>/dev/null || \
               grep -q "^[[:space:]]*function[[:space:]]*${func_name}" "$config" 2>/dev/null; then
                echo -e "${IVORY}  ✓ Found in:${RESET} ${BOLD}${config}${RESET}"
                found=true
            fi
        fi
    done
    
    if ! $found; then
        echo -e "${IVORY}  • Check:${RESET} ~/.zshrc, ~/.zshenv, ~/.zprofile"
        echo -e "${IVORY}  • Or:${RESET} \$ZDOTDIR/* if ZDOTDIR is set"
        echo -e "${IVORY}  • Or:${RESET} Loaded from a plugin/framework"
    fi
}

# --- Function: Search for alias definition in config files ---
search_alias_source() {
    local alias_name="$1"
    local found=false
    
    # Common zsh config locations
    local config_files=(
        "$HOME/.zshrc"
        "$HOME/.zshenv"
        "$HOME/.zprofile"
        "$HOME/.config/zsh/.zshrc"
        "$HOME/.zsh/aliases.zsh"
        "$HOME/.aliases"
    )
    
    # Also check if ZDOTDIR is set
    if [ -n "${ZDOTDIR:-}" ]; then
        config_files+=("$ZDOTDIR/.zshrc")
        config_files+=("$ZDOTDIR/.zshenv")
    fi
    
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            if grep -q "^[[:space:]]*alias[[:space:]]*${alias_name}=" "$config" 2>/dev/null; then
                echo -e "${IVORY}  ✓ Found in:${RESET} ${BOLD}${config}${RESET}"
                found=true
            fi
        fi
    done
    
    if ! $found; then
        echo -e "${IVORY}  • Check:${RESET} ~/.zshrc, ~/.zshenv, ~/.aliases"
        echo -e "${IVORY}  • Or:${RESET} \$ZDOTDIR/* if ZDOTDIR is set"
        echo -e "${IVORY}  • Or:${RESET} Loaded from a plugin/framework (oh-my-zsh, etc.)"
    fi
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

# --- Argument validation ---
if [ -z "${1:-}" ]; then
    echo -e "${PINK}Error: Please provide a command name.${RESET}"
    echo -e "${SKY}Usage: $0 <command-name>${RESET}"
    echo -e "${SKY}Example: $0 ls${RESET}"
    exit 1
fi

cmd="$1"

# --- Header ---
echo -e "\n\t${PINK2}━━━ NixOS Binary Inspector ━━━${RESET}"
echo -e "${SKY}Analyzing: ${BOLD}${cmd}${RESET}"
echo

# --- Step 1: Resolve command via command -v ---
cmd_path="$(command -v -- "$cmd" 2>/dev/null || true)"

if [ -z "$cmd_path" ]; then
    echo -e "${RED}✗ Command not found: ${cmd}${RESET}"
    exit 2
fi

echo -e "${PINK}➤ Resolved path:${RESET} ${cmd_path}"

# --- Check if builtin/function/alias ---
case "$cmd_path" in
    /*)
        # It's a file path, continue with Nix analysis
        ;;
    *)
        # It's a builtin/function/alias - use different analysis
        analyze_shell_command "$cmd"
        exit 0
        ;;
esac

# --- Step 2: Resolve symlinks ---
if ! command -v readlink >/dev/null 2>&1; then
    echo -e "${RED}✗ Error: readlink command not found${RESET}"
    exit 3
fi

real_path="$(readlink -f -- "$cmd_path" 2>/dev/null)"

if [ -z "$real_path" ]; then
    echo -e "${RED}✗ Error: Could not resolve real path${RESET}"
    exit 4
fi

echo -e "${IVORY}➤ Real path (resolved):${RESET} ${real_path}"
echo

# --- Step 3: Verify Nix store path ---
if ! echo "$real_path" | grep -q '^/nix/store/'; then
    echo -e "${RED}✗ This binary is NOT from the Nix store.${RESET}"
    echo -e "${SKY}  Location: ${real_path}${RESET}"
    exit 0
fi

# Extract store path (format: /nix/store/hash-name-version)
store_path="$(echo "$real_path" | grep -o '^/nix/store/[^/]*')"
echo -e "${BOLD}━━━ Nix Store Information ━━━${RESET}"
echo -e "${IVORY}Store path:${RESET} ${store_path}"

# --- Step 4: Derivation information ---
if ! command -v nix-store >/dev/null 2>&1; then
    echo -e "${AMBER}⚠ Warning: nix-store command not available${RESET}"
    exit 0
fi

echo
echo -e "${SKY}➤ Derivation Details:${RESET}"

# Get the derivation that built this store path
drv_path="$(nix-store --query --deriver "$store_path" 2>/dev/null || true)"

if [ -n "$drv_path" ] && [ "$drv_path" != "unknown-deriver" ]; then
    echo -e "${IVORY}  Derivation:${RESET} ${BROWN}${drv_path}${RESET}"
    
    # Extract package name from derivation path
    pkg_name="$(basename "$drv_path" .drv | sed 's/^[^-]*-//')"
    echo -e "${IVORY}  Package:${RESET} ${BOLD}${pkg_name}${RESET}"
else
    echo -e "${AMBER}  ⚠ Derivation information not available${RESET}"
fi

# --- Step 5: Dependencies ---
echo
echo -e "${SKY}➤ Direct Dependencies:${RESET}"

# Query direct runtime dependencies
deps="$(nix-store --query --references "$store_path" 2>/dev/null || true)"

if [ -n "$deps" ]; then
    dep_count=0
    while IFS= read -r dep; do
        # Skip self-reference
        if [ "$dep" != "$store_path" ]; then
            dep_name="$(basename "$dep")"
            echo -e "${IVORY}  • ${dep_name}${RESET}"
            dep_count=$((dep_count + 1))
        fi
    done <<< "$deps"
    
    if [ "$dep_count" -eq 0 ]; then
        echo -e "${SKY}  (No external dependencies)${RESET}"
    else
        echo -e "${BOLD}  Total: ${dep_count} dependencies${RESET}"
    fi
else
    echo -e "${SKY}  (Unable to query dependencies)${RESET}"
fi

# --- Step 6: Closure size ---
echo
echo -e "${SKY}➤ Storage Information:${RESET}"

# Get closure size (all dependencies)
closure_size="$(nix-store --query --requisites "$store_path" 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | cut -f1 || echo "unknown")"
echo -e "${IVORY}  Closure size:${RESET} ${BOLD}${closure_size}${RESET}"

# Individual package size
pkg_size="$(du -sh "$store_path" 2>/dev/null | cut -f1 || echo "unknown")"
echo -e "${IVORY}  Package size:${RESET} ${pkg_size}"

# Binary file size
binary_size="$(du -h "$real_path" 2>/dev/null | cut -f1 || echo "unknown")"
echo -e "${IVORY}  Binary size:${RESET} ${binary_size}"

# --- Step 7: Additional metadata ---
echo
echo -e "${SKY}➤ Additional Information:${RESET}"

# Check if the store path is valid
if nix-store --query --valid-derivers "$store_path" >/dev/null 2>&1; then
    echo -e "${IVORY}  Status:${RESET} ${BOLD}✓ Valid store path${RESET}"
else
    echo -e "${AMBER}  Status: ⚠ Store path validity unknown${RESET}"
fi

# Count total closure dependencies
total_deps="$(nix-store --query --requisites "$store_path" 2>/dev/null | wc -l || echo "0")"
echo -e "${IVORY}  Total closure deps:${RESET} ${total_deps}"

# --- Footer ---
echo
echo -e "${PINK2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

exit 0


