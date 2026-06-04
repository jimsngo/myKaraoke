#!/bin/bash
# Library: optimize_volume.sh

optimize_volume() {
    # 1. Reload the latest relative assets from json
    load_assets

    echo "🎛️  Select which track to normalize & optimize volume:"
    echo " 1) Instruments Only (For Karaoke Video generation)"
    echo " 2) Mixed Audio      (For Lyrics Video generation)"
    read -p "Selection [1/2]: " track_choice

    local SOURCE_REL_PATH=""
    local JSON_KEY=""
    local FILE_SUFFIX=""
    local TARGET_DIR=""

    if [[ "$track_choice" == "1" ]]; then
        SOURCE_REL_PATH="$INSTRUMENTS_ONLY"
        JSON_KEY="instruments_only"
        FILE_SUFFIX="instruments_optimized"
        TARGET_DIR="$INPUT_DIR/Instruments"
    elif [[ "$track_choice" == "2" ]]; then
        SOURCE_REL_PATH="$MAIN_AUDIO"
        JSON_KEY="main_audio"
        FILE_SUFFIX="mixed_optimized"
        TARGET_DIR="$INPUT_DIR/Mixed_Audio"
    else
        echo "❌ Invalid choice. Returning to menu."
        return 1
    fi

    # Sanity Check: Ensure the target asset exists in the JSON configuration
    if [[ -z "$SOURCE_REL_PATH" ]]; then
        echo "❌ Error: No track found registered under '$JSON_KEY' in assets.json!"
        return 1
    fi

    # Convert relative path from JSON to absolute path for execution on Mac
    local ABS_INPUT_PATH="$PROJECT_DIR/$SOURCE_REL_PATH"

    if [[ ! -f "$ABS_INPUT_PATH" ]]; then
        echo "❌ Error: Physical file missing at $ABS_INPUT_PATH"
        return 1
    fi

    # 2. Extract Names for Output Creation
    local BASE_NAME=$(basename "$ABS_INPUT_PATH")
    local EXT="${BASE_NAME##*.}"
    local TRACK_NAME="${BASE_NAME%.*}"
    
    # Remove older suffix tags if reprocessing an already optimized version
    TRACK_NAME=$(echo "$TRACK_NAME" | sed -E 's/_(instruments|vocals|mixed)?(_optimized)?$//')

    local NEW_BASE_NAME="${TRACK_NAME}_${FILE_SUFFIX}.$EXT"
    local ABS_OUTPUT_PATH="$TARGET_DIR/$NEW_BASE_NAME"
    local REL_OUTPUT_PATH="inputs/$(basename "$TARGET_DIR")/$NEW_BASE_NAME"

    # 3. Analyze Audio Peak Volume
    echo "🔍 Analyzing current peak volume level..."
    local PEAK_DB=$(ffmpeg -i "$ABS_INPUT_PATH" -af "volumedetect" -vn -f null - 2>&1 | grep "max_volume:" | awk '{print $5}')
    
    # Calculate target scale matching your previous threshold configuration (-0.2 dB offset safety)
    local ADJUSTMENT=$(echo "scale=2; 0.0 - $PEAK_DB - 0.2" | bc)

    echo "📊 Detected Max: ${PEAK_DB} dB | Clean adjustment target: ${ADJUSTMENT} dB"
    
    # 4. Process and Save relative updates
    read -p "Confirm normalization and update assets.json? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "🚀 Normalizing audio track stream..."
        ffmpeg -y -i "$ABS_INPUT_PATH" -af "volume=${ADJUSTMENT}dB" "$ABS_OUTPUT_PATH"
        
        # Write the updated clean relative path directly back into the inputs sub-block
        jq --arg k "$JSON_KEY" --arg p "$REL_OUTPUT_PATH" '.inputs[$k] = $p' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
        
        load_assets
        echo "✅ Success: Saved to '$REL_OUTPUT_PATH' and registered in assets.json!"
    else
        echo "⏭️  Operation canceled."
    fi
}