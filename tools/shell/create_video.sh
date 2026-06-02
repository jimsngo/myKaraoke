#!/bin/bash

# 1. Self-detect the project directory (The folder where THIS script is located)
# This finds the directory of the script, then moves up one level to the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

create_karaoke() {
    local INST="$1"
    local SUB="$2"
    local BG="$3"

    # 2. Force the output folder into the project root
    local OUTPUT_DIR="$PROJECT_ROOT/outputs"
    mkdir -p "$OUTPUT_DIR"
    
    local FILENAME=$(basename "$INST")
    local SONG_NAME="${FILENAME%.*}"
    local OUTPUT_FILE="$OUTPUT_DIR/${SONG_NAME}_karaoke.mp4"

    # 3. Validation
    if [[ ! -f "$INST" ]]; then
        echo "❌ Error: Instrumental file not found at: $INST"
        return 1
    fi

    # 4. Get Audio Duration
    local DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INST")

    echo "🎬 Rendering Karaoke for: $SONG_NAME"
    echo "Saving to: $OUTPUT_FILE"

    # 5. FFmpeg Command
    local VF_FILTER=""
    [[ -f "$SUB" ]] && VF_FILTER="subtitles='${SUB//\'/\\\'}'"

    ffmpeg -y -stream_loop -1 -i "$BG" -i "$INST" \
           ${VF_FILTER:+-vf "$VF_FILTER"} \
           -t "$DURATION" \
           -c:v libx264 -crf 20 -c:a aac -b:a 192k "$OUTPUT_FILE"
    
    # Only show success if FFmpeg actually finished
    if [ $? -eq 0 ]; then
        echo "✅ Success! Karaoke saved to: $OUTPUT_FILE"
    else
        echo "❌ FFmpeg failed to render the video."
    fi
}

create_karaoke "$1" "$2" "$3"