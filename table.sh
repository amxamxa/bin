#!/usr/bin/env bash
# ============================================================================
# Auto Table Renderer
# ============================================================================
# 
# NAME: auto-table5.sh
# 
# PURPOSE:
#   Reads pipe-delimited data from a file and renders it as a formatted
#   ASCII table in the terminal. The script creates an appealing tabular
#   representation for terminal output with automatic column width calculation.
# 
# USAGE:
#   ./auto-table5.sh [OPTIONS] <data-file>
# 
# OPTIONS:
#   -d, --debug    Enable debug mode
#   -q, --quiet    Disable debug mode (default: quiet mode)
#   -h, --help     Show this help message
# 
# INPUT FORMAT:
#   Input file must contain pipe-separated values:
#   value1|value2
#   more_data|additional_data
# 
# OUTPUT:
#   A formatted table with borders, colored edges, and proper column alignment.
#   Uses only ASCII characters for maximum compatibility across all terminals.
# 
# FEATURES:
#   - Automatic column width calculation based on content
#   - ANSI 24-bit True Color support
#   - Debug mode with detailed processing information
#   - ASCII-only characters (no Unicode issues)
#   - Input validation and error handling
#   - Terminal width awareness
# 
# EXAMPLES:
#   ./auto-table5.sh data.txt           # Quiet mode (default, no debug)
#   ./auto-table5.sh -d data.txt        # Enable debug mode
#   ./auto-table5.sh --debug data.txt   # Enable debug mode
#   ./auto-table5.sh -q data.txt        # Explicit quiet mode (same as default)
#   ./auto-table5.sh -h                 # Show help
# 
# AUTHOR: amxamxa
# VERSION: 1.6
# CHANGES:
#   - Changed default debug mode to false (quiet by default)
#   - Updated help text and examples to reflect new defaults
# ============================================================================

# ----------------------------------------------------------------------------
# Global Variables and Defaults
# ----------------------------------------------------------------------------
DEBUG=false  # Default: quiet mode (no debug)
FILE=""     # Input file

# ----------------------------------------------------------------------------
# Function: show_help
# ----------------------------------------------------------------------------
show_help() {
    echo "Auto Table Renderer - Format pipe-delimited data as ASCII tables"
    echo ""
    echo "Usage: $0 [OPTIONS] <data-file>"
    echo ""
    echo "Options:"
    echo "  -d, --debug    Enable debug mode (detailed processing information)"
    echo "  -q, --quiet    Disable debug mode (default: quiet)"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 data.txt                 # Display table quietly (no debug)"
    echo "  $0 -d data.txt              # Display table with debug info"
    echo "  $0 --debug data.txt         # Explicitly enable debug mode"
    echo "  $0 -q data.txt              # Explicit quiet mode (default)"
    echo "  $0 -h                       # Show this help"
    echo ""
    echo "Input format: Pipe-separated values (value1|value2)"
    echo "Output: Formatted ASCII table with colored borders"
    exit 0
}

# ----------------------------------------------------------------------------
# Function: debug_log
# ----------------------------------------------------------------------------
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo -e "${c}[DEBUG]${r} $1" >&2
    fi
}

# ----------------------------------------------------------------------------
# Configuration: Color Codes (ANSI 24-bit True Color)
# ----------------------------------------------------------------------------
# Border colors: Yellow text on dark blue background
c="\033[38;2;252;222;90m\033[48;2;0;0;139m"
# Success messages: Green text on dark green background  
g="\033[38;2;0;255;0m\033[48;2;0;100;0m"
# Error messages: Light red text on dark red background
red="\033[38;2;240;128;128m\033[48;2;139;0;0m"
# Info messages: Cyan text on dark cyan background
info="\033[38;2;64;224;208m\033[48;2;0;139;139m"
# Reset all formatting
r="\033[0m"

# ----------------------------------------------------------------------------
# Command Line Argument Parsing
# ----------------------------------------------------------------------------
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -q|--quiet)
            DEBUG=false
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            echo -e "${red}Error: Unknown option '$1'${r}" >&2
            echo -e "${info}Use '$0 -h' for help${r}" >&2
            exit 1
            ;;
        *)
            # First non-option argument is the file
            if [ -z "$FILE" ]; then
                FILE="$1"
                shift
            else
                echo -e "${red}Error: Multiple files specified: '$FILE' and '$1'${r}" >&2
                echo -e "${info}Use '$0 -h' for help${r}" >&2
                exit 1
            fi
            ;;
    esac
done

debug_log "Debug mode: $DEBUG"

# ----------------------------------------------------------------------------
# Input Validation: File Argument
# ----------------------------------------------------------------------------
if [ -z "$FILE" ]; then
    echo -e "${red}Error: No input file specified${r}" >&2
    echo ""
    echo -e "${info}Usage: $0 [OPTIONS] <data-file>${r}"
    echo -e "${info}Use '$0 -h' for detailed help${r}"
    exit 1
fi

debug_log "Input file: $FILE"

# ----------------------------------------------------------------------------
# Input Validation: File Existence Check
# ----------------------------------------------------------------------------
if [[ -f "$FILE" ]]; then
    debug_log "File found: $FILE"
    echo -e "${g}Reading data from $FILE...${r}"
    
    # Check file size
    filesize=$(wc -l < "$FILE")
    debug_log "File contains $filesize lines"
    
    if [[ $filesize -eq 0 ]]; then
        echo -e "${red}Warning: File is empty${r}" >&2
    fi
else
    echo -e "${red}Error: File '$FILE' not found${r}" >&2
    echo -e "${info}Tip: Check file path and permissions${r}" >&2
    exit 1
fi

# ----------------------------------------------------------------------------
# Border Characters: ASCII Only for Maximum Compatibility
# ----------------------------------------------------------------------------
# We use only ASCII characters to avoid � (replacement character) issues
# that occur when terminals don't support Unicode glyphs
v="|"  # Vertical pipe character (ASCII 124)
h="-"  # Horizontal dash character (ASCII 45)
corner="+"  # Corner character for table junctions (ASCII 43)

debug_log "Using ASCII border characters (no Unicode issues)"

# ----------------------------------------------------------------------------
# Function: Clean String
# ----------------------------------------------------------------------------
# Purpose: Removes non-printable characters and replaces tabs
# Why: Ensures clean output and prevents formatting issues
# Method: Uses tr to delete non-printable chars, sed to replace tabs
clean_string() {
    echo "$1" | tr -cd '\11\12\15\40-\176' | sed 's/\t/    /g'
}

# ----------------------------------------------------------------------------
# Data Processing: Read and Clean Input File
# ----------------------------------------------------------------------------
debug_log "Starting data processing..."

# Read file into array and clean it
mapfile -t rows < <(sed 's/^[[:space:]"]*//;s/[[:space:]"]*$//;/^$/d' "$FILE")

# Check if data exists
if [[ ${#rows[@]} -eq 0 ]]; then
    echo -e "${red}Error: No valid data found in file${r}" >&2
    echo -e "${info}Expected format: value1|value2${r}" >&2
    exit 1
fi

debug_log "Records found: ${#rows[@]}"

# ----------------------------------------------------------------------------
# Column Width Calculation
# ----------------------------------------------------------------------------
# Algorithm:
# 1. Initialize width counters w1 and w2 to 0
# 2. For each row, split by pipe delimiter
# 3. Clean and measure each field's length
# 4. Update max width if current field is longer
# 5. Add 2 characters padding (as requested)
#
# Note: w1 and w2 represent the content width ONLY
# Additional padding is added in the rendering phase
w1=0  # Maximum width for first column content
w2=0  # Maximum width for second column content

debug_log "Calculating column widths..."

for row in "${rows[@]}"; do
    # Split row by pipe delimiter
    IFS='|' read -r a b <<< "$row"
    
    # Clean strings of special characters
    a=$(clean_string "$(echo "$a" | xargs)")
    b=$(clean_string "$(echo "$b" | xargs)")
    
    # Update maximum widths
    if [[ ${#a} -gt $w1 ]]; then
        w1=${#a}
        debug_log "New max width column 1: $w1 (value: '$a')"
    fi
    
    if [[ ${#b} -gt $w2 ]]; then
        w2=${#b}
        debug_log "New max width column 2: $w2 (value: '$b')"
    fi
done

# Add 2 characters padding to each column (as requested)
w1=$((w1 + 2))
w2=$((w2 + 2))

debug_log "Final column widths: Column 1 = ${w1} chars, Column 2 = ${w2} chars"

# Check for overly wide tables
terminal_width=$(tput cols 2>/dev/null || echo 80)
total_width=$((w1 + w2 + 4))  # +4 for borders and spaces between columns

if [[ $total_width -gt $terminal_width ]]; then
    echo -e "${red}Warning: Table width ($total_width) exceeds terminal width ($terminal_width)${r}" >&2
    echo -e "${info}Tip: Consider increasing terminal width or shortening data${r}" >&2
fi

# ----------------------------------------------------------------------------
# TABLE RENDERING EXPLANATION
# ----------------------------------------------------------------------------
# The table rendering follows this ASCII art pattern:
#
#    +---------------------+-----------------------------------+
#    | column1 content     | column2 content                   |
#    +---------------------+-----------------------------------+
#
# Components:
# 1. Corners (+): ASCII 43, mark table intersections
# 2. Horizontal lines (-): ASCII 45, form top and bottom borders
# 3. Vertical lines (|): ASCII 124, separate columns
# 4. Content padding: Each cell has spaces on both sides
#
# Width Calculation for Rendering:
# - Each column has w1/w2 width INCLUDING 2-character padding
# - In cell rendering: we use printf "%-*s" which left-aligns content
# - The asterisk (*) gets replaced by (w1-2) to leave room for spaces
# - Result: " content " fits exactly in w1 characters
#
# Border Drawing:
# - Top/Bottom: +------+------+ where each dash section is w1/w2 chars long
# - Middle: No horizontal separators between rows for cleaner look
#
# COLOR SCHEME:
# - Entire table border (horizontal lines and corners) uses border color (c)
# - Content areas use terminal default color (r)
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Function: draw_horizontal_line
# ----------------------------------------------------------------------------
# Purpose: Draws a horizontal separator line for the table
# How it works:
# 1. Entire line uses border color (c) for consistent appearance
# 2. Uses printf to create w1 dashes for first column border
# 3. Uses printf to create w2 dashes for second column border
# 4. Adds corner characters at intersections
# Note: w1 and w2 already include the 2-character padding
draw_horizontal_line() {
    # Fixed: Entire horizontal line uses border color
    # Format: corner + w1 dashes + corner + w2 dashes + corner
    printf "${c}%s%s%s%s%s${r}\n" \
        "$corner" \
        "$(printf "%${w1}s" | tr ' ' '-')" \
        "$corner" \
        "$(printf "%${w2}s" | tr ' ' '-')" \
        "$corner"
    debug_log "Horizontal line drawn (widths: $w1+$w2)"
}

# ----------------------------------------------------------------------------
# Table Rendering: Main Output
# ----------------------------------------------------------------------------
# RENDERING PROCESS EXPLANATION:
# 1. TOP BORDER: draw_horizontal_line creates the complete colored top frame
# 2. DATA ROWS: Each row is rendered with:
#    - Colored vertical borders (c) at edges
#    - Reset color (r) for content area
#    - Left-aligned content with calculated padding
# 3. BOTTOM BORDER: Same as top for closure
#
# CELL FORMATTING DETAILS:
# - printf "%-*s": Left-align string with dynamic width
# - (w1-2): Leaves room for 2 spaces around content (1 space each side)
# - Result: "| content " has exactly w1 characters including spaces
# - Borders: Colored to distinguish from content
# ----------------------------------------------------------------------------

debug_log "Starting table rendering..."

# Top border
draw_horizontal_line

# Process and display each data row
row_count=0
for row in "${rows[@]}"; do
    row_count=$((row_count + 1))
    
    # Split row by pipe delimiter
    IFS='|' read -r a b <<< "$row"
    
    # Clean strings
    a=$(clean_string "$(echo "$a" | xargs)")
    b=$(clean_string "$(echo "$b" | xargs)")
    
    # Render table row with colored borders and uncolored content
    # Format: | content1 | content2 |
    printf "${c}%s${r} %-*s ${c}%s${r} %-*s ${c}%s${r}\n" \
        "$v" "$((w1-2))" "$a" "$v" "$((w2-2))" "$b" "$v"
    
    debug_log "Row $row_count rendered: '$a' | '$b'"
done

# Bottom border
draw_horizontal_line

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
debug_log "Table rendering completed"
# echo -e "${g}Table successfully rendered (${#rows[@]} rows)${r}"

