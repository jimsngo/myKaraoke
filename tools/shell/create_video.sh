#!/bin/bash
PROJECT_ROOT="/Users/jim/myKaraoke"
PRESETS="$PROJECT_ROOT/assets.json"
INPUT_DIR="$PROJECT_ROOT/inputs"
OUTPUT_DIR="$PROJECT_ROOT/outputs"

# Load inputs from JSON if arguments are missing
INST="${1:-$INPUT_DIR/$(jq -r '.instruments_only' "$PRESETS")}"
SUB="${2:-$INPUT_DIR/$(jq -r '.subtitles' "$PRESETS")}"
BG="${3:-$INPUT_DIR/$(jq -r '.background' "$PRESETS")}"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Generate a valid output filename
FILENAME=$(basename "$INST")
SONG_NAME="${FILENAME%.*}"
OUTPUT_FILE="$OUTPUT_DIR/${SONG_NAME}_karaoke.mp4"

# Validate
if [[ ! -f "$INST" ]]; then
    echo "❌ Error: Instrumental file not found at: $INST"
    exit 1
fi

# Get Duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INST")

# FFmpeg Command (Force mapping!)
VF_FILTER=""
[[ -f "$SUB" ]] && VF_FILTER="subtitles='${SUB//\'/\\\'}'"

echo "🎬 Rendering Karaoke..."
ffmpeg -y -stream_loop -1 -i "$BG" -i "$INST" \
       ${VF_FILTER:+-vf "$VF_FILTER"} \
       -map 0:v:0 -map 1:a:0 \
       -t "$DURATION" \
       -c:v libx264 -c:a aac -b:a 192k \
       "$OUTPUT_FILE"