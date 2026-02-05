#!/usr/bin/env bash

# Display images in the current directory using chafa.
# Supports common image formats: png, jpg, jpeg, gif, bmp, tiff, webp.
# Usage: ./showPicInCWD.sh [--help|-h]

# Define UI colors (Cyberpunk theme)
COL_USER="\033[38;2;0;17;204m\033[48;2;147;112;219m" 
COL_ACCENT="\033[38;2;32;0;21m\033[48;2;163;64;217m"     
VIO="\033[38;2;255;0;53m\033[48;2;34;0;82m"              
RESET="\033[0m"                                           # Reset to default terminal colors

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo -e "${VIO}Usage: $0 [--help|-h]${RESET}"
  echo ""
  echo -e "${COL_USER}This script displays images in the current directory using 'chafa'.
   Supports common image formats: png, jpg, jpeg, gif, bmp, tiff, webp.${RESET}"
  echo ""
  echo -e "${VIO}Options:${RESET}"
  echo "  --help, -h    Show this help message and exit."
  exit 0
fi

# Find all image files in the current directory
images=()
for ext in png jpg jpeg gif bmp tiff webp PNG JPG JPEG GIF BMP TIFF WEBP; do
  images+=(*."$ext")
done

# Remove non-existent files (glob returns literal string if no match)
images=($(printf "%s\n" "${images[@]}" | grep -v '\*'))

# Check if any images were found
if [ ${#images[@]} -eq 0 ]; then
  echo -e "${COL_USER}No images found in the current directory.${RESET}"
  exit 1
fi

# Display each image using chafa
for img in "${images[@]}"; do
  clear
  
  # Use chafa to display the image with specified parameters
  if ! chafa --optimize 8 --format kitty --animate off "$img"; then
    echo -e "${COL_USER}Failed to display image: $(basename "$img")${RESET}"
  fi
  
  # Display text below the image
  
  echo -e "\t${COL_ACCENT}Displaying:\t $(basename "$img")${RESET}\t ${VIO}Press 'q' to quit or Enter to continue...${RESET}"

  # Wait for user input
  read -s -N 1 input
  if [[ "$input" == "q" ]]; then
    break
  fi
done

echo -e "${COL_ACCENT}Slideshow ended.${RESET}"
