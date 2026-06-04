#!/bin/bash
# Library: strip_audio.sh

strip_audio() {
    load_assets

    local INPUT_FILE=""
    local SOURCE_IS_PRESET=false

    echo "🎬 Select video processing target:"
    if [[ -n "$BACKGROUND" ]]; then
        echo " 1) Use current asset: $BACKGROUND"
        echo " 2) Pick a new file from your Mac"
        read -p "Selection [1/2]: " target_choice
        
        if [[ "$target_choice" == "1" ]]; then
            INPUT_FILE="$PROJECT_DIR/$BACKGROUND"
            SOURCE_IS_PRESET=true
        fi
    fi

    # Fallback to file picker if option 2 was chosen or no background is currently loaded
    if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE=$(pick_file "Select video to strip audio from:" "mp4,mov,mkv,avi")
        [[ -z "$INPUT_FILE" ]] && { echo "⏭️ Operation canceled."; return 1; }
    fi

    # Ensure the physical file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "❌ Error: Video file missing at $INPUT_FILE"
        return 1
    fi

    local BASE_NAME=$(basename "$INPUT_FILE")
    local EXT="${BASE_NAME##*.}"
    local FILE_NAME="${BASE_NAME%.*}"

    # Clean up duplicate suffix markers if rewriting an already processed file
    FILE_NAME=$(echo "$FILE_NAME" | sed 's/_no_audio$//')

    # Establish output mapping inside inputs/Background/
    mkdir -p "$INPUT_DIR/Background"
    local ABS_OUTPUT_PATH="$INPUT_DIR/Background/${FILE_NAME}_no_audio.$EXT"
    local REL_OUTPUT_PATH="inputs/Background/${FILE_NAME}_no_audio.$EXT"

    echo "✂️  Stripping audio from: $BASE_NAME..."
    
    # Run ffmpeg (fast copy mode, strips audio without re-encoding video)
    if ffmpeg -y -i "$INPUT_FILE" -an -c:v copy "$ABS_OUTPUT_PATH"; then
        echo "✅ Success! File saved to: $REL_OUTPUT_PATH"

        # Ask if you want to make this the primary video background asset
        echo ""
        read -p "Set this silent video as your active background in assets.json? (y/N): " update_json
        if [[ "$update_json" =~ ^[Yy]$ ]]; then
            jq --arg p "$REL_OUTPUT_PATH" '.inputs.background = $p' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
            load_assets
            echo "✅ Single source of truth updated!"
        fi
    else
        echo "❌ ffmpeg error: Failed to strip audio."
        return 1
    fi
}