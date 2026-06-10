#!/bin/bash
# Library: tools/shell/demucs_split.sh

demucs_split() {
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local INPUT_DIR="$PROJECT_DIR/inputs"
    local PRESETS="$PROJECT_DIR/assets.json"
    
    # 1. Fetch the already initialized mixed_audio asset path directly from your database
    local REL_MIXED=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")
    local ABS_MIXED="$PROJECT_DIR/$REL_MIXED"
    
    if [[ -z "$REL_MIXED" ]] || [[ ! -f "$ABS_MIXED" ]]; then
        echo "❌ Error: No active mixed_audio session found registered. Please run Option 1 first!"
        return 1
    fi

    local FILE_NAME=$(basename "$ABS_MIXED")
    local TRACK_NAME="${FILE_NAME%_Mixed.*}" # Extracts the clean base song title name prefix
    local EXT="${FILE_NAME##*.}"

    echo "🤖 Starting AI Stem Separation Engine..."
    echo "🎵 Target Source Audio: $FILE_NAME"
    
    mkdir -p "$INPUT_DIR/instruments" "$INPUT_DIR/vocals" "$INPUT_DIR/stems"

    # Run Demucs explicitly targeting our pre-registered mix
    demucs --two-stems=vocals -o "$INPUT_DIR/stems" "$ABS_MIXED"

    if [[ $? -ne 0 ]]; then
        echo "❌ Error: AI Stem extraction processing step failed."
        return 1
    fi

    # Locate generated stems inside intermediate directory layers
    local DEMUCS_OUTPUT_DIR=$(find "$INPUT_DIR/stems/htdemucs" -maxdepth 1 -type d ! -path "$INPUT_DIR/stems/htdemucs" | head -n 1)
    local FOUND_VOCALS=$(find "$DEMUCS_OUTPUT_DIR" -name "vocals.$EXT" | head -n 1)
    local FOUND_INST=$(find "$DEMUCS_OUTPUT_DIR" -name "no_vocals.$EXT" | head -n 1)
    
    if [[ -n "$FOUND_VOCALS" && -n "$FOUND_INST" ]]; then
        local FINAL_VOCALS_PATH="$INPUT_DIR/vocals/${TRACK_NAME}_vocals.$EXT"
        local FINAL_INST_PATH="$INPUT_DIR/instruments/${TRACK_NAME}_instruments.$EXT"
        
        mv "$FOUND_VOCALS" "$FINAL_VOCALS_PATH"
        mv "$FOUND_INST" "$FINAL_INST_PATH"
        rm -rf "$INPUT_DIR/stems" # Clean up temporary workspace noise
        
        local REL_VOCALS="inputs/vocals/${TRACK_NAME}_vocals.$EXT"
        local REL_INST="inputs/instruments/${TRACK_NAME}_instruments.$EXT"
        
        # Save structural registration mappings seamlessly back to assets database keys
        local temp_json=$(mktemp)
        jq --arg i "$REL_INST" --arg v "$REL_VOCALS" \
           '.inputs.instruments_only = $i | .inputs.vocals_only = $v' \
           "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
           
        echo "✅ AI Stem Separation successful!"
        echo "📝 Registered Instruments Stem: $REL_INST"
        echo "📝 Registered Vocals Stem: $REL_VOCALS"
    else
        echo "❌ Error: Demucs finished but script could not relocate output audio stems."
        return 1
    fi
}