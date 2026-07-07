#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 9 Module
# Script: tools/shell/create_video.sh
# Purpose: Multiplexes subtitles and instrumental audio onto the background canvas.
# ==============================================================================

create_karaoke_video() {
    PROJECT_DIR="${PROJECT_DIR:-/Users/jim/myKaraoke}"
    local PROJECT_ROOT="$PROJECT_DIR"
    local PRESETS="$PROJECT_ROOT/assets.json"

    echo "⏳ Loading production assets from database registry..."
    
    local LIVE_BG=$(jq -r '.inputs.background // ""' "$PRESETS")
    local LIVE_INST=$(jq -r '.inputs.instruments_only // ""' "$PRESETS")
    
    local ABS_BG
    if [[ "$LIVE_BG" == /* ]]; then ABS_BG="$LIVE_BG"; else ABS_BG="$PROJECT_ROOT/$LIVE_BG"; fi

    local ABS_INST
    if [[ "$LIVE_INST" == /* ]]; then ABS_INST="$LIVE_INST"; else ABS_INST="$PROJECT_ROOT/$LIVE_INST"; fi
    
    local PROD_SUB_KEY=$(jq -r '.inputs.subtitles_production_ass // .inputs.subtitles_ass' "$PRESETS")
    local ABS_SUB
    if [[ "$PROD_SUB_KEY" == /* ]]; then ABS_SUB="$PROD_SUB_KEY"; else ABS_SUB="$PROJECT_ROOT/$PROD_SUB_KEY"; fi

    local SONG_NAME="karaoke_output"
    if [[ -n "$LIVE_INST" ]]; then
        local BASE_NAME=$(basename "$ABS_INST")
        SONG_NAME=$(echo "${BASE_NAME%.*}" | sed -E 's/_(instruments|vocals|mixed)?(_optimized)?$//')
    fi

    # Uniform capitalized folder tracking
    local TARGET_DIR="$PROJECT_ROOT/outputs/Karaoke"
    mkdir -p "$TARGET_DIR"
    local ABS_OUTPUT_FILE="$TARGET_DIR/${SONG_NAME}_karaoke.mp4"
    local REL_OUTPUT_FILE="outputs/Karaoke/${SONG_NAME}_karaoke.mp4"

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
    echo "⏱️  Timeline Target:     $DURATION seconds"
    echo ""

    ffmpeg -nostdin -y -stream_loop -1 -i "$ABS_BG" -i "$ABS_INST" \
           -vf "$vf_filter" \
           -map 0:v:0 -map 1:a:0 \
           -t "$DURATION" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k \
           "$ABS_OUTPUT_FILE"

    if [[ $? -eq 0 && -f "$ABS_OUTPUT_FILE" ]]; then
        echo ""
        echo "✅ Video rendering complete!"
        
        # 💡 AUTOMATED REGISTRATION TRIGGER
        local temp_json=$(mktemp)
        jq --arg p "$REL_OUTPUT_FILE" '.outputs.karaoke_video = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "💾 assets.json auto-updated with karaoke release location: $REL_OUTPUT_FILE"
    else
        echo "❌ ERROR: ffmpeg rendering processing pipeline failed."
        return 1
    fi
}

create_karaoke_video