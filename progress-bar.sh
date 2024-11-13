#!/usr/bin/env sh

# Get the total number of files
total_files=$(find . -type f | wc -l)

# Initialize a counter
counter=0

# Function to display the progress bar
display_progress() {
  local progress=$((counter * 100 / total_files))
  local done=$((progress * 4 / 10))
  local left=$((40 - done))
  local fill=$(printf "%${done}s")
  local empty=$(printf "%${left}s")
  
  # Print the progress bar
  printf "\rProgress : [${fill// /#}${empty// /-}] ${progress}%%"
}

# Export the function to be used by the subshell
export -f display_progress

# Process each file
find . -type f | while read -r file; do
  sha256sum "$file"  # Replace this line with your actual processing command
  counter=$((counter + 1))
  display_progress
done

# Print a newline at the end
echo
