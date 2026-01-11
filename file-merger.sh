#!/usr/bin/env bash

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --output)
            ZIELDATEI="$2"
            shift 2
            ;;
        --sources)
            shift
            QUELLDATEIEN=("$@")
            break
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if output file and source files are provided
if [[ -z "$ZIELDATEI" || -z "${QUELLDATEIEN[*]}" ]]; then
    echo "Usage: $0 --output <target_file> --sources <source_file1> [source_file2] ..." >&2
    exit 1
fi

# Check if the output file already exists
if [[ -e "$ZIELDATEI" ]]; then
    echo "Warning: The output file '$ZIELDATEI' already exists and will be overwritten." >&2
fi

# Initialize the output file (clear or create it)
: > "$ZIELDATEI"

# Iterate over all source files
for DATEI in "${QUELLDATEIEN[@]}"; do
    # Check if the file exists and is readable
    if [[ ! -f "$DATEI" ]]; then
        echo "Error: The file '$DATEI' does not exist or is not a regular file." >&2
        continue
    fi

    # Append the content of the file to the output file
    cat "$DATEI" >> "$ZIELDATEI"
done

echo "The files have been successfully merged into '$ZIELDATEI'."
