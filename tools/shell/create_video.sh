#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 9 Module
# Script: tools/shell/create_video.sh
# Purpose: Renders production karaoke visuals using instrumentals and stylized ASS.
# ==============================================================================

create_karaoke_video() {
    local PROJECT_ROOT="/Users/jim/myKaraoke"
    local PRESETS="$PROJECT_ROOT/assets.json"

    echo "⏳ Loading production assets from dashboard environment..."
    
    # Direct mapping for media assets
    local ABS_BG="$PROJECT_ROOT/$BACKGROUND_VID"
    local ABS_INST="$PROJECT_ROOT/$INSTRUMENTS_ONLY"
    
    # 🎯 TARGET FIX: Explicitly parse the master Aegisub file key from blueprints
    local PROD_SUB_KEY=$(jq -r '.inputs.subtitles_production_ass // .inputs.subtitles_ass' "$PRESETS")
    local ABS_SUB="$PROJECT_ROOT/$PROD_SUB_KEY"

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

    # Dependency check validation
    if [[ ! -f "$ABS_BG" || ! -f "$ABS_INST" || ! -f "$ABS_SUB" ]]; then
        echo "❌ ERROR: Cannot proceed with multiplexing."
        echo "   Missing: $( [[ ! -f "$ABS_SUB" ]] && echo "[Master Subtitles: $PROD_SUB_KEY] " )$( [[ ! -f "$ABS_BG" ]] && echo "[Background] " )$( [[ ! -f "$ABS_INST" ]] && echo "[Instrumental]" )"
        return 1
    fi

    local DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_INST")
    local vf_filter="subtitles='${ABS_SUB//\'/\\\'}'"

    echo ""
    echo "🎬 Rendering Production-Grade Karaoke Video..."
    echo "🎵 Song Identification: $SONG_NAME"
    echo "📝 Using Subtitle Track: $(basename "$ABS_SUB")"
    echo "⏱️  Timeline Target:     $DURATION seconds"
    echo "🎥 Deploying ffmpeg processing stream..."
    echo ""

    ffmpeg -y -stream_loop -1 -i "$ABS_BG" -i "$ABS_INST" \
           -vf "$vf_filter" \
           -map 0:v:0 -map 1:a:0 \
           -t "$DURATION" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k \
           "$ABS_OUTPUT_FILE"

    if [[ $? -eq 0 && -f "$ABS_OUTPUT_FILE" ]]; then
        echo ""
        echo "✅ Video rendering complete!"
        local temp_json=$(mktemp)
        jq --arg p "$REL_OUTPUT_FILE" '.outputs.karaoke_video = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "💾 Asset map updated with video release location."
    else
        echo "❌ ERROR: ffmpeg rendering processing pipeline failed."
        return 1
    fi
}
