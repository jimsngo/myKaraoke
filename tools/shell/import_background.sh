#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 8 Module
# Script: tools/shell/import_background.sh
# Purpose: Pre-renders and loops background video assets to match audio timelines.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ mixed_audio ]
# ==============================================================================

import_background() {
    # Define local path references independent of external shell scopes
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local INPUT_DIR="$PROJECT_DIR/inputs"
    local PRESETS="$PROJECT_DIR/assets.json"
    local JSON_GUARD="$PROJECT_DIR/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Enforce variable names are aligned before timeline calculations
    local REQUIRED_ASSET_KEYS=(
        "mixed_audio"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active Processing Engine Runs Safely Below ---
    # FIXED: Re-aligned to fetch mixed_audio to stay completely in sync with Option 1
    local REL_AUDIO=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")

    if [[ -z "$REL_AUDIO" || ! -f "$PROJECT_DIR/$REL_AUDIO" ]]; then
        echo "❌ Error: No master mixed audio file found registered in assets.json."
        echo "   Please run Option 1 first so we can calculate timeline durations!"
        return 1
    fi

    local ABS_AUDIO="$PROJECT_DIR/$REL_AUDIO"

    echo "🎬 Select ONE background video loop asset:"
    local FILE=$(pick_file "Select background video loop source:" "mp4,mov,mkv,avi")
    
    [[ -z "$FILE" ]] && { echo "⏭️ Selection canceled."; return 1; }

    local BG_BASE=$(basename "$FILE")
    local BG_NAME="${BG_BASE%.*}"

    local TARGET_DIR="$INPUT_DIR/background"
    mkdir -p "$TARGET_DIR"
    
    local ABS_OUTPUT_PATH="$TARGET_DIR/${BG_NAME}_optimized_background.mp4"
    local REL_OUTPUT_PATH="inputs/background/${BG_NAME}_optimized_background.mp4"

    echo "📁 Target Output: $REL_OUTPUT_PATH"
    echo ""
    echo "🎥 Choose Optimization Profile Style:"
    echo "1) Scale to 1080p HD (Default)"
    echo "2) Fit Dimensions Exactly (No Resize)"
    echo "3) High Precision Slow Comp (Pristine Visuals)"
    read -p "Select choice [1-3, or Press Enter for Default]: " bg_choice

    local SCALE_FILTER="-vf scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
    local PRESET_PROFILE="fast"
    local CRF_PROFILE="22"

    if [[ "$bg_choice" == "2" ]]; then
        SCALE_FILTER=""
    elif [[ "$bg_choice" == "3" ]]; then
        PRESET_PROFILE="veryslow"
        CRF_PROFILE="18"
    fi

    echo ""
    echo "⏳ Calculating length of reference audio track..."
    local AUDIO_LEN=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_AUDIO")
    
    echo "⚙️  Pre-rendering background loop to cover total duration (${AUDIO_LEN}s)..."
    echo "🎥 Processing via FFmpeg..."
    
    ffmpeg -y -stream_loop -1 -i "$FILE" -t "$AUDIO_LEN" \
        $SCALE_FILTER \
        -c:v libx264 \
        -preset "$PRESET_PROFILE" \
        -crf "$CRF_PROFILE" \
        -pix_fmt yuv420p \
        -an "$ABS_OUTPUT_PATH"

    if [ $? -eq 0 ] && [ -f "$ABS_OUTPUT_PATH" ]; then
        echo ""
        echo "✅ Success: Pre-lengthened video track generated!"
        echo "📁 Saved to: $REL_OUTPUT_PATH"
        
        read -p "Register this file as the active background loop in assets.json? (Y/n): " confirm
        confirm=${confirm:-y} 

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local temp_json=$(mktemp)
            jq --arg p "$REL_OUTPUT_PATH" '.inputs.background = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
            echo "📝 Registered background loop mapping successfully!"
        fi
        return 0
    else
        echo "❌ Error: FFmpeg video processing calculation hit an error loop."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    import_background
fi