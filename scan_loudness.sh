#!/bin/bash

# Helper for macOS file picker
pick_file() {
    local prompt="$1"
    osascript -e "POSIX path of (choose file with prompt \"$prompt\")" 2>/dev/null
}

echo "Select the file you want to scan for loudness..."
FILE=$(pick_file "Select Audio/Video file")

if [[ -z "$FILE" ]]; then
    echo "❌ No file selected. Aborting."
    exit 1
fi

echo "----------------------------------------------------------------"
echo "Scanning: $(basename "$FILE")"
echo "Please wait..."
echo "----------------------------------------------------------------"

# Scan the file
ffmpeg -i "$FILE" -af loudnorm=I=-16:print_format=summary -f null -

echo "----------------------------------------------------------------"
read -p "Scan complete. Press Enter to exit..."
