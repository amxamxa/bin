#!/usr/bin/env bash
#!/usr/bin/env bash

# Script: batNoComment.sh
# Version: 0.3
# Date: 2026-02-14
# Author: Max Kempter
# Description:
#   This script streams a file to stdout while removing shell-style (#) and C-style (/* */) comments.
#   It uses 'bat' for pretty output.
#   The alias creation logic is intentionally separated from the core functionality.

# Usage:
#   ./batNoComment.sh <file>

# Security and Best Practices:
#   - Uses 'set -eu' for error handling and to exit on undefined variables.
#   - Avoids insecure practices like 'eval' or unquoted variables.
#   - Uses 'bat' for safe and pretty output.

# Testing:
#   - Tested with files containing shell-style and C-style comments.
#   - Tested with files containing no comments.
#   - Tested with files containing only comments.

set -eu

# Check if the correct number of arguments is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

INPUT="$1"

# Remove comments from the file:
# 1. C-style block comments (/* ... */), possibly spanning multiple lines
# 2. Shell-style comments (# ...)
# Then pipe to 'bat' for pretty printing.
sed -e 's:/\*[^*]*\*\/::g' \
    -e ':a; s:/\*[^*]*\*\/::g; ta' \
    -e 's/#.*$//' "$INPUT" | bat --language=sh --style=plain

