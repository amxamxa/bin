#!/usr/bin/env bash
################################################################################
# Function: ARTEM_IMG (ASCII Art Image Viewer using artem)
# Purpose: Display images as ASCII/Unicode art using the artem Rust tool
# Author: Optimized version with comprehensive error handling
# Usage: ARTEM_IMG [directory] [--width N] [--scale N] [--delay N] [options]
#
# Features:
#   - Multiple image format support (jpg, jpeg, png, gif, webp, svg)
#   - Configurable output dimensions and scaling
#   - Automatic dependency checking (artem via cargo)
#   - Safe glob expansion and file handling
#   - Color/grayscale output options
#   - Custom character set support
#   - Customizable delay between images
#   - Recursive directory search
#
# Dependencies:
#   - artem (cargo install artem)
#
# Exit Codes:
#   0 - Success (at least one image displayed)
#   1 - Missing dependencies or no images found
#   2 - Invalid arguments
################################################################################

# ANSI Color definitions using $'...' syntax for proper interpretation
readonly PURPLE=$'\033[0;35m'
readonly CYAN=$'\033[0;36m'
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly BLUE=$'\033[0;34m'
readonly RESET=$'\033[0m'

# Default configuration values
readonly DEFAULT_WIDTH=80
readonly DEFAULT_SCALE=1.0
readonly DEFAULT_DELAY=1.5

# Supported image formats (case-insensitive through shopt)
readonly -a SUPPORTED_FORMATS=(
    "jpg" "jpeg" "png" "gif" 
    "webp" "svg" "bmp" "tiff"
)

################################################################################
# Main function: Display images as ASCII/Unicode art using artem
# Arguments:
#   $1 - Target directory (optional, default: current directory)
#   --width N - Output width in columns (default: 80)
#   --height N - Output height in rows (optional)
#   --scale N - Scaling factor (default: 1.0)
#   --characters <STRING> - Custom character set for rendering
#   --no-color - Disable color output (grayscale only)
#   --delay N - Delay in seconds between images (default: 1.5)
#   --recursive - Search subdirectories recursively
#   --help - Display usage information
################################################################################
ARTEM_IMG() {
    # Local variables for configuration
    local target_dir="."
    local width=$DEFAULT_WIDTH
    local height=""
    local scale=$DEFAULT_SCALE
    local characters=""
    local use_color=true
    local delay=$DEFAULT_DELAY
    local recursive=false
    
    ############################################################################
    # Parse command line arguments
    ############################################################################
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --width)
                if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    printf "%s Error: --width requires a positive integer %s\n" \
                        "$RED" "$RESET" >&2
                    return 2
                fi
                width="$2"
                shift 2
                ;;
            --height)
                if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    printf "%s Error: --height requires a positive integer %s\n" \
                        "$RED" "$RESET" >&2
                    return 2
                fi
                height="$2"
                shift 2
                ;;
            --scale)
                if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                    printf "%s Error: --scale requires a positive number %s\n" \
                        "$RED" "$RESET" >&2
                    return 2
                fi
                scale="$2"
                shift 2
                ;;
            --characters)
                if [[ -z "$2" ]]; then
                    printf "%s Error: --characters requires a string argument %s\n" \
                        "$RED" "$RESET" >&2
                    return 2
                fi
                characters="$2"
                shift 2
                ;;
            --no-color)
                use_color=false
                shift
                ;;
            --delay)
                if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                    printf "%s Error: --delay requires a positive number %s\n" \
                        "$RED" "$RESET" >&2
                    return 2
                fi
                delay="$2"
                shift 2
                ;;
            --recursive)
                recursive=true
                shift
                ;;
            --help)
                _artem_img_usage
                return 0
                ;;
            -*)
                printf "%s Error: Unknown option '%s' %s\n" "$RED" "$1" "$RESET" >&2
                _artem_img_usage
                return 2
                ;;
            *)
                # First positional argument is target directory
                if [[ -n "$target_dir" ]] && [[ "$target_dir" != "." ]]; then
                    printf "%s Error: Multiple directories specified %s\n" \
                        "$RED" "$RESET" >&2
                    return 2
                fi
                target_dir="$1"
                shift
                ;;
        esac
    done

    ############################################################################
    # Validate target directory
    ############################################################################
    if [[ ! -d "$target_dir" ]]; then
        printf "%s Error: Directory '%s' does not exist %s\n" \
            "$RED" "$target_dir" "$RESET" >&2
        return 1
    fi

    ############################################################################
    # Check dependencies
    ############################################################################
    if ! _check_artem_dependency; then
        return 1
    fi

    ############################################################################
    # Enable case-insensitive globbing and nullglob
    ############################################################################
    shopt -s nocaseglob nullglob

    ############################################################################
    # Build glob patterns for all supported formats
    ############################################################################
    local -a glob_patterns=()
    for ext in "${SUPPORTED_FORMATS[@]}"; do
        if [[ "$recursive" == true ]]; then
            glob_patterns+=("$target_dir/**/*.$ext")
        else
            glob_patterns+=("$target_dir/*.$ext")
        fi
    done

    ############################################################################
    # Collect all matching image files
    ############################################################################
    local -a image_files=()
    for pattern in "${glob_patterns[@]}"; do
        for file in $pattern; do
            if [[ -f "$file" ]]; then
                image_files+=("$file")
            fi
        done
    done

    # Restore shell options
    shopt -u nocaseglob nullglob

    ############################################################################
    # Validate that images were found
    ############################################################################
    if [[ ${#image_files[@]} -eq 0 ]]; then
        printf "%s Warning: No image files found in '%s' %s\n" \
            "$YELLOW" "$target_dir" "$RESET" >&2
        printf "Supported formats: %s\n" "${SUPPORTED_FORMATS[*]}"
        return 1
    fi

    printf "%s Found %d image(s) to display %s\n\n" \
        "$GREEN" "${#image_files[@]}" "$RESET"

    ############################################################################
    # Build artem command line options
    ############################################################################
    local -a artem_opts=()
    
    # Add width option
    artem_opts+=("--width" "$width")
    
    # Add height option if specified
    if [[ -n "$height" ]]; then
        artem_opts+=("--height" "$height")
    fi
    
    # Add scale option
    artem_opts+=("--scale" "$scale")
    
    # Add character set if specified
    if [[ -n "$characters" ]]; then
        artem_opts+=("--characters" "$characters")
    fi
    
    # Add color option
    if [[ "$use_color" == false ]]; then
        artem_opts+=("--no-color")
    fi

    ############################################################################
    # Process each image file
    ############################################################################
    local success_count=0
    local failure_count=0

    for file in "${image_files[@]}"; do
        # Display current file being processed
        printf "\n\t%s➜ %s%s\n" "$PURPLE" "$file" "$RESET"
        
        # Attempt to render image with artem
        # Note: artem outputs to stdout, errors to stderr
        if artem "${artem_opts[@]}" "$file" 2>/dev/null; then
            ((success_count++))
            
            # Pause between images for better viewing experience
            # Use read with timeout for interruptible delay
            if [[ "$delay" != "0" ]]; then
                read -t "$delay" -n 1 -s || true
            fi
        else
            # Capture and analyze error
            local error_msg
            error_msg=$(artem "${artem_opts[@]}" "$file" 2>&1 >/dev/null)
            printf "%s Error: Failed to process '%s' %s\n" \
                "$RED" "$file" "$RESET" >&2
            printf "  Reason: %s\n" "$error_msg" >&2
            ((failure_count++))
        fi
    done

    ############################################################################
    # Summary output
    ############################################################################
    printf "\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$CYAN" "$RESET"
    printf "%s✓ Alle Bilder verarbeitet: %d erfolgreich, %d fehlgeschlagen %s\n" \
        "$GREEN" "$success_count" "$failure_count" "$RESET"

    # Return appropriate exit code
    if [[ $success_count -eq 0 ]]; then
        return 1
    fi
    return 0
}

################################################################################
# Helper function: Check if artem is installed
# Returns:
#   0 - artem is available
#   1 - artem is missing
################################################################################
_check_artem_dependency() {
    if ! command -v artem &>/dev/null; then
        printf "%s Error: 'artem' is not installed %s\n" "$RED" "$RESET" >&2
        printf "\n%s Installation options:%s\n" "$YELLOW" "$RESET" >&2
        printf "  1. Via cargo (Rust package manager):\n" >&2
        printf "     cargo install artem\n\n" >&2
        printf "  2. Via NixOS (declarative):\n" >&2
        printf "     # Add to configuration.nix:\n" >&2
        printf "     environment.systemPackages = with pkgs; [ artem ];\n\n" >&2
        printf "  3. Via nix-shell (temporary):\n" >&2
        printf "     nix-shell -p artem\n\n" >&2
        return 1
    fi

    # Display artem version for verification
    local version
    version=$(artem --version 2>/dev/null || echo "unknown")
    printf "%s Using artem version: %s %s\n" "$BLUE" "$version" "$RESET"
    
    return 0
}

################################################################################
# Helper function: Display usage information
################################################################################
_artem_img_usage() {
    cat << EOF
${CYAN}Usage:${RESET}
    ARTEM_IMG [directory] [options]

${CYAN}Options:${RESET}
    --width N           Output width in columns (default: 80)
    --height N          Output height in rows (optional, auto-calculated)
    --scale N           Scaling factor (default: 1.0)
    --characters STR    Custom character set for rendering
                        Examples: " .:-=+*#%@" or "blocks" or "dense"
    --no-color          Disable color output (grayscale only)
    --delay N           Delay in seconds between images (default: 1.5)
    --recursive         Search subdirectories recursively
    --help              Display this help message

${CYAN}Examples:${RESET}
    ARTEM_IMG                               # Display all images in current dir
    ARTEM_IMG ~/Pictures                    # Display from specific directory
    ARTEM_IMG --width 120 --scale 2         # Larger output, scaled up
    ARTEM_IMG --no-color                    # Grayscale ASCII art
    ARTEM_IMG --characters " .:-=#@"        # Custom character set
    ARTEM_IMG --recursive ~/Photos          # Search all subdirectories
    ARTEM_IMG --delay 0 --width 60          # No delay, smaller output

${CYAN}Supported formats:${RESET}
    ${SUPPORTED_FORMATS[*]}

${CYAN}Dependencies:${RESET}
    - artem (Rust-based ASCII art generator)
      Install: cargo install artem
      Or: Add 'artem' to NixOS configuration.nix

${CYAN}Notes:${RESET}
    - Color output requires terminal with true color support
    - Press any key during delay to skip to next image
    - Use Ctrl+C to abort processing
EOF
}

################################################################################
# Diagnostic function: Test ARTEM_IMG functionality
################################################################################
_test_artem_img() {
    echo "=== ARTEM_IMG Diagnostic Test ==="
    
    # Test 1: Dependency check
    echo "Test 1: Checking dependencies..."
    _check_artem_dependency && echo "✓ Dependencies OK" || echo "✗ Dependencies missing"
    
    # Test 2: Color output
    echo "Test 2: Color codes"
    printf "%s COLOR TEST %s\n" "$PURPLE" "$RESET"
    
    # Test 3: Function defined
    echo "Test 3: Function defined"
    type ARTEM_IMG
    
    # Test 4: Check artem capabilities
    if command -v artem &>/dev/null; then
        echo "Test 4: Artem help output"
        artem --help 2>&1 | head -n 5
    fi
    
    echo "=== Diagnostic Complete ==="
}

# Uncomment to run diagnostic when sourcing this script
# _test_artem_img
