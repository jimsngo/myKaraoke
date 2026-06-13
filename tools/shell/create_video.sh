#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 9 Module
# Script: tools/shell/create_video.sh
# Purpose: Renders production karaoke visuals using instrumentals and stylized ASS.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ mixed_audio, instruments_only, subtitles_ass, background ]
# ==============================================================================

create_karaoke_video() {
    local PROJECT_ROOT="/Users/jim/myKaraoke"
    local PRESETS="$PROJECT_ROOT/assets.json"

    # --- Active Video Render Engine Runs Safely Below ---
    echo "⏳ Loading production assets from dashboard environment..."
    
    # Direct mapping to global variables exported by Karaoke_Dashboard.sh
    local ABS_BG="$PROJECT_ROOT/$BACKGROUND_VID"
    local ABS_INST="$PROJECT_ROOT/$INSTRUMENTS_ONLY"
    local ABS_SUB="$PROJECT_ROOT/$SUBTITLES_ASS"

    # Extract clean song name from the instrumental path
    local SONG_NAME="karaoke_output"
    if [[ -n "$INSTRUMENTS_ONLY" ]]; then
        local BASE_NAME=$(basename "$ABS_INST")
        SONG_NAME=$(echo "${BASE_NAME%.*}" | sed -E 's/_(instruments|vocals|mixed)?(_optimized)?$//')
    fi

    local TARGET_DIR="$PROJECT_ROOT/outputs/karaoke"
    mkdir -p "$TARGET_DIR"
    local ABS_OUTPUT_FILE="$TARGET_DIR/${SONG_NAME}_karaoke.mp4"
    local REL_OUTPUT_FILE="outputs/karaoke/${SONG_NAME}_karaoke.mp4"

    # Verify files exist on disk before rendering
    if [[ ! -f "$ABS_BG" ]] || [[ ! -f "$ABS_INST" ]] || [[ ! -f "$ABS_SUB" ]]; then
        echo "❌ Error: One or more rendering dependencies are missing from disk."
        echo "   Ensure Background, Instruments, and Subtitles are properly set."
        return 1
    fi

    # Calculate track length for the video cutoff boundary
    local DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_INST")
    local vf_filter="subtitles='${ABS_SUB//\'/\\\'}'"

    echo ""
    echo "🎬 Rendering Production-Grade Karaoke Video..."
    echo "🎵 Song Identification: $SONG_NAME"
    echo "⏱️  Timeline Target:     $DURATION seconds"
    echo "🎥 Deploying ffmpeg processing stream..."
    echo ""

    # Execute multiplex encode stream
    ffmpeg -y -stream_loop -1 -i "$ABS_BG" -i "$ABS_INST" \
           -vf "$vf_filter" \
           -map 0:v:0 -map 1:a:0 \
           -t "$DURATION" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k \
           "$ABS_OUTPUT_FILE"

    if [[ $? -eq 0 && -f "$ABS_OUTPUT_FILE" ]]; then
        echo ""
        echo "✅ Video rendering complete!"
        # Update the master assets map with the final location
        local temp_json=$(mktemp)
        jq --arg p "$REL_OUTPUT_FILE" '.outputs.karaoke_video = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "📂 Saved to: $REL_OUTPUT_FILE"
        return 0
    else
        echo "❌ Error: FFmpeg multiplexing stream encountered an export failure."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    create_karaoke_video
fi