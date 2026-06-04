#!/bin/bash

demucs_split() {
    # 1. Sanity Check / Confirmation Prompt
    load_assets
    echo "🔍 [Sanity Check] Checking current track status..."
    
    if [[ -n "$MAIN_AUDIO" ]]; then
        echo "⚠️  Current active song path in assets.json:"
        echo "    $MAIN_AUDIO"
        echo ""
    else
        echo "ℹ️  No song is currently loaded in assets.json."
        echo ""
    fi

    read -p "Do you want to extract stems for a new song? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "⏭️  Operation canceled. Returning to main menu."
        return 0
    fi

    # 2. Ensure capitalized subfolder layouts match your blueprint
    mkdir -p "$INPUT_DIR/Mixed_Audio" "$INPUT_DIR/Instruments" "$INPUT_DIR/Vocals" "$INPUT_DIR/stems"

    # 3. Pick the source track file
    local SELECTED_FILE=$(pick_file "Select audio track to split:" "mp3,wav,aiff,flac")
    [[ -z "$SELECTED_FILE" ]] && return 1

    local EXT="${SELECTED_FILE##*.}"
    local BASE_NAME=$(basename "$SELECTED_FILE")
    local TRACK_NAME="${BASE_NAME%.*}"
    
    # Target absolute path on your Mac and relative path for JSON storage
    local TARGET_MAIN_AUDIO="$INPUT_DIR/Mixed_Audio/$BASE_NAME"
    local REL_MAIN_AUDIO="inputs/Mixed_Audio/$BASE_NAME"
    
    # 🚚 Copy the original mixed track over to the project directory
    echo "🚚 Archiving mixed track to $REL_MAIN_AUDIO..."
    cp "$SELECTED_FILE" "$TARGET_MAIN_AUDIO"
    
    # Update main_audio inside assets.json
    jq --arg path "$REL_MAIN_AUDIO" '.inputs.main_audio = $path' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
    load_assets

    echo "🎵 Demucs separating tracks for: $TRACK_NAME..."
    
    # 4. Process split execution
    if [[ "$EXT" == "mp3" ]]; then
        demucs --two-stems=vocals --mp3 -n htdemucs "$TARGET_MAIN_AUDIO" -o "$INPUT_DIR/stems"
    else
        demucs --two-stems=vocals -n htdemucs "$TARGET_MAIN_AUDIO" -o "$INPUT_DIR/stems"
    fi
    
    # 5. Target demucs output paths
    local DEMUCS_OUTPUT_DIR="$INPUT_DIR/stems/htdemucs/$TRACK_NAME"
    local FOUND_VOCALS=$(find "$DEMUCS_OUTPUT_DIR" -name "vocals.$EXT" | head -n 1)
    local FOUND_INST=$(find "$DEMUCS_OUTPUT_DIR" -name "no_vocals.$EXT" | head -n 1)
    
    if [[ -n "$FOUND_VOCALS" && -n "$FOUND_INST" ]]; then
        local FINAL_VOCALS_PATH="$INPUT_DIR/Vocals/${TRACK_NAME}_vocals.$EXT"
        local FINAL_INST_PATH="$INPUT_DIR/Instruments/${TRACK_NAME}_instruments.$EXT"
        
        # Move into designated tree directories
        mv "$FOUND_VOCALS" "$FINAL_VOCALS_PATH"
        mv "$FOUND_INST" "$FINAL_INST_PATH"
        
        # Clean workspace
        rm -rf "$INPUT_DIR/stems"
        
        # Relative paths for JSON tracking
        local REL_VOCALS="inputs/Vocals/${TRACK_NAME}_vocals.$EXT"
        local REL_INST="inputs/Instruments/${TRACK_NAME}_instruments.$EXT"
        
        # 6. Commit absolute paths back down into assets.json
        jq --arg i "$REL_INST" --arg v "$REL_VOCALS" \
           '.inputs.instruments_only = $i | .inputs.vocals_only = $v' \
           "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
        
        load_assets
        echo "✅ Option 1 Complete: Stems saved and registered to assets.json."
    else
        echo "❌ Error: Could not locate extracted stems."
    fi
}