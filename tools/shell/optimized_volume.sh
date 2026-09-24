#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 3 Module
# Script: tools/shell/optimized_volume.sh
# Purpose: Measures and standardizes audio loudness parameters using ffmpeg loudnorm.
#          NON-DESTRUCTIVE: Saves to a new file and updates assets.json.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ mixed_audio, instruments_only ]
# ==============================================================================

optimize_volume() {
    # --- Local Environment Variables Block ---
    local PROJECT_ROOT="$PROJECT_DIR"
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
    local REL_TARGET=""
    local JSON_KEY=""

    if [[ "$target_choice" == "1" ]]; then
        TARGET_FILE="$ABS_MAIN"
        REL_TARGET="$REL_MAIN"
        JSON_KEY="mixed_audio"
    elif [[ "$target_choice" == "2" ]]; then
        TARGET_FILE="$ABS_INST"
        REL_TARGET="$REL_INST"
        JSON_KEY="instruments_only"
    else
        echo "⏭️  Selection canceled. Returning to dashboard."
        return 0
    fi

    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "❌ Error: Target audio file missing at: $TARGET_FILE"
        return 1
    fi

    echo "🎛️  Running loudness parameter pass on: $(basename "$TARGET_FILE")..."

    local STATS=$(ffmpeg -nostdin -i "$TARGET_FILE" -filter:a loudnorm=print_format=json -f null - 2>&1 | pcregrep -M '\{[\s\S]*\}')
    
    if [[ -z "$STATS" ]]; then
        echo "❌ Error: Failed to analyze audio dynamics."
        return 1
    fi

    local I_INPUT=$(echo "$STATS" | jq -r '.input_i')
    local TP_INPUT=$(echo "$STATS" | jq -r '.input_tp')
    local LRA_INPUT=$(echo "$STATS" | jq -r '.input_lra')
    local thresh_input=$(echo "$STATS" | jq -r '.input_thresh')

    # Create the non-destructive new file paths
    local REL_OUT="${REL_TARGET%.*}_normalized.mp3"
    local OUT_FILE="$PROJECT_ROOT/$REL_OUT"

    echo "⚡ Applying precision volume normalization adjustments..."
    ffmpeg -y -nostdin -i "$TARGET_FILE" -filter:a \
    "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=${I_INPUT}:measured_TP=${TP_INPUT}:measured_LRA=${LRA_INPUT}:measured_thresh=${thresh_input}:linear=true" \
    -b:a 192k "$OUT_FILE"

    if [[ $? -eq 0 ]] && [[ -f "$OUT_FILE" ]]; then
        echo "✅ Headroom peaks safely standardized!"
        echo "💾 Saved non-destructive copy: $OUT_FILE"

        # === AUTO-UPDATE ASSETS.JSON ===
        python3 -c '
import sys, json
assets_file = sys.argv[1]
json_key = sys.argv[2]
new_path = sys.argv[3]
try:
    with open(assets_file, "r") as f:
        data = json.load(f)
    if "inputs" not in data:
        data["inputs"] = {}
    data["inputs"][json_key] = new_path
    with open(assets_file, "w") as f:
        json.dump(data, f, indent=4)
    print(f"📝 Automatically linked {json_key} to normalized file in assets.json")
except Exception as e:
    print(f"⚠️ Warning: Could not update assets.json: {e}")
' "$PRESETS" "$JSON_KEY" "$REL_OUT"
        # =======================================

    else
        echo "❌ Error: ffmpeg failed to export normalized audio file."
        [[ -f "$OUT_FILE" ]] && rm -f "$OUT_FILE"
        return 1
    fi
}