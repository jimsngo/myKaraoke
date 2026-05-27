#!/bin/bash

# Configuration
CRF_VAL=23
PRESET="medium"
OUTPUT_DIR="$HOME/myKaraoke/outputs"
INPUT_DIR="$HOME/myKaraoke/inputs"
mkdir -p "$OUTPUT_DIR"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <instrumental_file> <lyrics_ass_file>"
    exit 1
fi

AUDIO_FILE="$1"
ASS_FILE="$2"
OUTPUT_FILE="$OUTPUT_DIR/$(basename "${AUDIO_FILE%.*}")_output.mp4"

# Check for Background file
BG_VIDEO=$(ls "$INPUT_DIR"/*.mp4 2>/dev/null | head -n 1)
BG_IMAGE=$(ls "$INPUT_DIR"/*.{jpg,png} 2>/dev/null | head -n 1)

if [[ -z "$BG_VIDEO" && -z "$BG_IMAGE" ]]; then
    echo "⚠️  No background file (mp4, jpg, png) found in inputs/."
    read -p "Would you like to (u)pload one, or (a)bort? " CHOICE
    if [[ "$CHOICE" == "u" ]]; then
        echo "Please upload your background file to inputs/ and run this command again."
        exit 1
    else
        echo "Aborting render."
        exit 1
    fi
fi

echo "🚀 Processing background..."

if [[ -n "$BG_VIDEO" ]]; then
    echo "🎥 Detected video loop: $(basename "$BG_VIDEO")"
    ffmpeg -stream_loop -1 -i "$BG_VIDEO" -i "$AUDIO_FILE" \
        -vf "subtitles='$ASS_FILE'" -c:v libx264 -crf $CRF_VAL -preset $PRESET \
        -c:a aac -b:a 192k -shortest "$OUTPUT_FILE"
elif [[ -n "$BG_IMAGE" ]]; then
    echo "🖼️  Detected image: $(basename "$BG_IMAGE")"
    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$AUDIO_FILE" \
        -vf "subtitles='$ASS_FILE',zoompan=z='min(zoom+0.0015,1.5)':d=125:s=1920x1080" \
        -c:v libx264 -crf $CRF_VAL -preset $PRESET \
        -c:a aac -b:a 192k -shortest "$OUTPUT_FILE"
fi

echo "✅ Success! Output saved to: $OUTPUT_FILE"
