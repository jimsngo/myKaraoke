#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 7 Module
# Script: tools/shell/strip_audio.sh
# Purpose: Strips audio streams from video assets to prepare silent backgrounds.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ background ]
# ==============================================================================

strip_audio() {
    # Define local path references independent of external shell scopes
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local INPUT_DIR="$PROJECT_DIR/inputs"
    local PRESETS="$PROJECT_DIR/assets.json"
    local JSON_GUARD="$PROJECT_DIR/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Ensure background key matches schema definitions
    local REQUIRED_ASSET_KEYS=(
        "background"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active Processing Engine Runs Safely Below ---
    local LIVE_BACKGROUND=$(jq -r '.inputs.background // ""' "$PRESETS")

    local INPUT_FILE=\"\"
    local SOURCE_IS_PRESET=false

    echo "🎬 Select video processing target:"
    if [[ -n "$LIVE_BACKGROUND" ]]; then
        echo " 1) Use current asset: $LIVE_BACKGROUND"
        echo " 2) Pick a new file from your Mac"
        read -p "Selection [1/2]: " target_choice
        
        if [[ "$target_choice" == "1" ]]; then
            INPUT_FILE="$PROJECT_DIR/$LIVE_BACKGROUND"
            SOURCE_IS_PRESET=true
        fi
    fi

    if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE=$(pick_file "Select video to strip audio from:" "mp4,mov,mkv,avi")
        if [[ -z "$INPUT_FILE" ]]; then
            echo "⏭️  Operation canceled."
            return 1
        fi
    fi

    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "❌ Error: Video file missing at $INPUT_FILE"
        return 1
    fi

    local BASE_NAME=$(basename "$INPUT_FILE")
    local EXT="${BASE_NAME##*.}"
    local FILE_NAME="${BASE_NAME%.*}"

    FILE_NAME=$(echo "$FILE_NAME" | sed 's/_no_audio$//')

    local TARGET_DIR="$INPUT_DIR/background"
    mkdir -p "$TARGET_DIR"
    
    local ABS_OUTPUT_PATH="$TARGET_DIR/${FILE_NAME}_no_audio.$EXT"
    local REL_OUTPUT_PATH="inputs/background/${FILE_NAME}_no_audio.$EXT"

    echo "✂️  Stripping audio from: $BASE_NAME..."
    
    if ffmpeg -y -i "$INPUT_FILE" -an -c:v copy "$ABS_OUTPUT_PATH"; then
        echo "✅ Success! File saved to: $REL_OUTPUT_PATH"

        echo ""
        read -p "Set this silent video as your active background in assets.json? (y/N): " update_json
        if [[ "$update_json" =~ ^[Yy]$ ]]; then
            local temp_json=$(mktemp)
            jq --arg p "$REL_OUTPUT_PATH" '.inputs.background = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
            echo "📝 Registered background video track asset."
        fi
        return 0
    else
        echo "❌ Error: FFmpeg failed to split audio stream."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    strip_audio
fi