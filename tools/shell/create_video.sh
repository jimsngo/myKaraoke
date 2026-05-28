#!/bin/bash
PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"
OUTPUT_DIR="$PROJECT_DIR/outputs"

AUDIO_FILE="$1"
ASS_FILE="$2"
BG_FILE="$3"
OUTPUT_FILE="$OUTPUT_DIR/$(basename "${AUDIO_FILE%.*}")_final.mp4"

echo "🚀 Rendering (Classic)..."
ffmpeg -y -stream_loop -1 -i "$BG_FILE" -i "$AUDIO_FILE" \
    -vf "subtitles='$ASS_FILE'" \
    -map 0:v -map 1:a -c:v libx264 -crf 23 -preset medium \
    -c:a aac -b:a 192k -shortest "$OUTPUT_FILE"