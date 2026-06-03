demucs_split() {
    # 1. Select the file
    local INPUT_FILE=$(pick_file "Select a mixed_audio track to split stems:" "mp3,wav,aiff,flac")
    [[ -z "$INPUT_FILE" ]] && return 1

    # 2. Get file details
    local EXT="${INPUT_FILE##*.}"
    local BASE_NAME=$(basename "$INPUT_FILE")
    local TRACK_NAME="${BASE_NAME%.*}"
    local STEMS_DIR="$INPUT_DIR/stems"
    
    # 3. Register input
    jq --arg f "$BASE_NAME" '.mixed_audio = $f' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
    load_assets

    echo "🎵 Splitting stems for: $TRACK_NAME..."
    
    # 4. Split (Dynamic format matching)
    if [[ "$EXT" == "mp3" ]]; then
        demucs --two-stems=vocals --mp3 -n htdemucs "$INPUT_FILE" -o "$STEMS_DIR"
    else
        demucs --two-stems=vocals -n htdemucs "$INPUT_FILE" -o "$STEMS_DIR"
    fi
    
    # 5. Locate and rename with Track Name + Suffix
    local DEMUCS_OUTPUT_DIR="$STEMS_DIR/htdemucs/$TRACK_NAME"
    local FOUND_VOCALS=$(find "$DEMUCS_OUTPUT_DIR" -name "vocals.$EXT" | head -n 1)
    local FOUND_INST=$(find "$DEMUCS_OUTPUT_DIR" -name "no_vocals.$EXT" | head -n 1)
    
    if [[ -n "$FOUND_VOCALS" && -n "$FOUND_INST" ]]; then
        # Use your TRACK_NAME to create custom names
        local NEW_VOCALS="${TRACK_NAME}_vocals.$EXT"
        local NEW_INST="${TRACK_NAME}_instruments.$EXT"
        
        # Move and rename using the unique names
        mv "$FOUND_VOCALS" "$INPUT_DIR/$NEW_VOCALS"
        mv "$FOUND_INST" "$INPUT_DIR/$NEW_INST"
        
        # Cleanup the nested Demucs directory
        rm -rf "$STEMS_DIR/htdemucs"
        
        # Update assets.json with the new unique filenames
        jq --arg i "$NEW_INST" --arg v "$NEW_VOCALS" \
           '.instruments_only = $i | .vocals_only = $v' \
           "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
        
        load_assets
        echo "✅ Success: Saved as '$NEW_VOCALS' and '$NEW_INST'."
    else
        echo "❌ Error: Could not locate stems."
    fi
}