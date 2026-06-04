#!/bin/bash

# --- CONFIGURATION ---
# Point this to where your input folder actually lives
INPUT_DIR="./inputs"
OUTPUT_NAME="background_loop.mp4"

# --- THE FUNCTION ---
make_background() {
    # 1. Ask for the file
    echo "Select your short background clip:"
    # This uses a simple file selection dialog if you are on macOS
    local INPUT_VIDEO=$(osascript -e 'POSIX path of (choose file with prompt "Select your background clip:")')
    
    # Clean up the path (remove trailing carriage return)
    INPUT_VIDEO=$(echo "$INPUT_VIDEO" | tr -d '\r')
    
    if [[ -z "$INPUT_VIDEO" ]]; then
        echo "No file selected. Exiting."
        exit 1
    fi

    echo "🎬 Processing: $INPUT_VIDEO"
    echo "Creating a 5-minute silent loop..."

    # 2. Run FFmpeg
    # -stream_loop -1: loops the input infinitely
    # -t 300: stops at 300 seconds (5 mins)
    # -an: removes all audio
    # -c:v copy: keeps original quality
    ffmpeg -stream_loop -1 -i "$INPUT_VIDEO" -t 300 -an -c:v copy "$OUTPUT_NAME"

    if [[ $? -eq 0 ]]; then
        echo "✅ Success! File created: $OUTPUT_NAME"
    else
        echo "❌ Error: ffmpeg failed. Check your input file."
    fi
}

# --- RUN IT ---
make_background