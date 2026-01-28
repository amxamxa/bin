#!/bin/sh
# Stream a file to stdout while removing shell-style (#) and C-style (/* */) comments.
# Uses 'bat' for pretty output.

set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

INPUT="$1"

# Remove:
# 1. C-style block comments (/* ... */), possibly spanning multiple lines
# 2. Shell-style comments (# ...)
# Then pipe to bat for pretty printing.
sed -e 's:/\*[^*]*\*\/::g' \
    -e ':a; s:/\*[^*]*\*/::g; ta' \
    -e 's/#.*$//' "$INPUT" | bat --language=sh --style=plain

