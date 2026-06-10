#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 3 Module
# Script: tools/shell/optimized_volume.sh
# Purpose: Measures and standardizes audio loudness parameters using ffmpeg loudnorm.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ mixed_audio, instruments_only ]
#
# Safeguard Mechanism:
#   Intercepts execution immediately during the local variables declaration phase. 
#   If a key was renamed in assets.json but left un-updated here, it halts execution
#   instantly to isolate the break, preventing silent downstream analysis failures.
# ==============================================================================

optimize_volume() {
    # --- Local Environment Variables Block ---
    local PROJECT_ROOT="/Users/jim/myKaraoke"
    local PRESETS="$PROJECT_ROOT/assets.json"
    local JSON_GUARD="$PROJECT_ROOT/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Declare the exact keys this option script relies on to execute
    local REQUIRED_ASSET_KEYS=(
        "mixed_audio"
        "instruments_only"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active Audio Processing Pipeline Runs Safely Below ---
    echo "🔊 Loading target audio assets from database..."
    
    local REL_MAIN=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")
    local REL_INST=$(jq -r '.inputs.instruments_only // ""' "$PRESETS")

    local ABS_MAIN="$PROJECT_ROOT/$REL_MAIN"
    local ABS_INST="$PROJECT_ROOT/$REL_INST"

    echo "Which audio asset layout would you like to standardize?"
    echo "1) Full Master Mixed Audio Track"
    echo "2) Instrumental Backing Stem"
    read -p "Select [1-2]: " target_choice

    local TARGET_FILE=""
    if [[ "$target_choice" == "1" ]]; then
        TARGET_FILE="$ABS_MAIN"
    elif [[ "$target_choice" == "2" ]]; then
        TARGET_FILE="$ABS_INST"
    else
        echo "⏭️  Selection canceled. Returning to dashboard."
        return 0
    fi

    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "❌ Error: Target audio file missing at: $TARGET_FILE"
        return 1
    fi

    echo "🎛️  Running loudness parameter pass on: $(basename "$TARGET_FILE")..."

    local STATS=$(ffmpeg -i "$TARGET_FILE" -filter:a loudnorm=print_format=json -f null - 2>&1 | pcregrep -M '\{[\s\S]*\}')
    
    if [[ -z "$STATS" ]]; then
        echo "❌ Error: Failed to analyze audio dynamics."
        return 1
    fi

    local I_INPUT=$(echo "$STATS" | jq -r '.input_i')
    local TP_INPUT=$(echo "$STATS" | jq -r '.input_tp')
    local LRA_INPUT=$(echo "$STATS" | jq -r '.input_lra')
    local thresh_input=$(echo "$STATS" | jq -r '.input_thresh')

    local TEMP_FILE="${TARGET_FILE%.*}_temp.mp3"

    echo "⚡ Applying precision volume normalization adjustments..."
    ffmpeg -y -i "$TARGET_FILE" -filter:a \
    "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=${I_INPUT}:measured_TP=${TP_INPUT}:measured_LRA=${LRA_INPUT}:measured_thresh=${thresh_input}:linear=true" \
    -b:a 192k "$TEMP_FILE"

    if [[ $? -eq 0 ]] && [[ -f "$TEMP_FILE" ]]; then
        mv "$TEMP_FILE" "$TARGET_FILE"
        echo "✅ Headroom peaks safely standardized down into original destination track file!"
    else
        echo "❌ Error: ffmpeg failed to export normalized audio file."
        [[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
        return 1
    fi
}