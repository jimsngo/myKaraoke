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
    local JSON_GUARD="$PROJECT_ROOT/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Mandating alignment over all core production targets
    local REQUIRED_ASSET_KEYS=(
        "mixed_audio"
        "instruments_only"
        "subtitles_ass"
        "background"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active Video Render Engine Runs Safely Below ---
    echo "⏳ Loading production assets from database..."
    
    # FIXED: Re-aligned keys to completely remove main_audio dependency
    local REL_MAIN=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")
    local REL_INST=$(jq -r '.inputs.instruments_only // ""' "$PRESETS")
    local REL_SUB=$(jq -r '.inputs.subtitles_ass // ""' "$PRESETS") 
    local REL_BG=$(jq -r '.inputs.background // ""' "$PRESETS")

    local ABS_MAIN="$PROJECT_ROOT/$REL_MAIN"
    local ABS_INST="$PROJECT_ROOT/$REL_INST"
    local ABS_SUB="$PROJECT_ROOT/$REL_SUB"
    local ABS_BG="$PROJECT_ROOT/$REL_BG"

    local SONG_NAME="karaoke_output"
    if [[ -n "$REL_MAIN" ]]; then
        local BASE_NAME=$(basename "$ABS_MAIN")
        SONG_NAME=$(echo "${BASE_NAME%.*}" | sed -E 's/_(instruments|vocals|mixed)?(_optimized)?$//')
    elif [[ -n "$REL_INST" ]]; then
        local BASE_NAME=$(basename "$ABS_INST")
        SONG_NAME=$(echo "${BASE_NAME%.*}" | sed -E 's/_(instruments|vocals|mixed)?(_optimized)?$//')
    fi

    local TARGET_DIR="$PROJECT_ROOT/outputs/karaoke"
    mkdir -p "$TARGET_DIR"
    local ABS_OUTPUT_FILE="$TARGET_DIR/${SONG_NAME}_karaoke.mp4"
    local REL_OUTPUT_FILE="outputs/karaoke/${SONG_NAME}_karaoke.mp4"

    if [[ ! -f "$ABS_BG" ]] || [[ ! -f "$ABS_INST" ]] || [[ ! -f "$ABS_SUB" ]]; then
        echo "❌ Error: One or more rendering dependencies are missing from disk."
        return 1
    fi

    local DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_INST")
    local VF_FILTER="subtitles='${ABS_SUB//\'/\\\'}'"

    echo ""
    echo "🎬 Rendering Production-Grade Karaoke Video..."
    echo "🎵 Song Identification: $SONG_NAME"
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