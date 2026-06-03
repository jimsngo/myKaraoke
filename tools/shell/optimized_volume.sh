#!/bin/bash
# Library: optimize_volume.sh
optimize_volume() {
    # 1. Select the file
    local INPUT_FILE=$(pick_file "Select audio track:" "mp3,wav,aiff,flac")
    [[ -z "$INPUT_FILE" ]] && return 1

    # 2. Ask for Classification
    echo "Classify this track to update assets.json:"
    echo " 1) Mixed - Vocals + Instrumental"
    echo " 2) Instrumentals only"
    read -p "Selection [1/2]: " type_choice

    local KEY=""
    if [[ "$type_choice" == "1" ]]; then KEY="mixed_audio"; 
    elif [[ "$type_choice" == "2" ]]; then KEY="instruments_only";
    else echo "Invalid choice. Aborting."; return 1; fi

    # 3. Analyze Peak
    echo "🔍 Analyzing..."
    local PEAK_DB=$(ffmpeg -i "$INPUT_FILE" -af "volumedetect" -vn -f null - 2>&1 | grep "max_volume:" | awk '{print $5}')
    local ADJUSTMENT=$(echo "scale=2; 0.0 - $PEAK_DB - 0.2" | bc)

    echo "📊 Detected Max: ${PEAK_DB} dB | Adjustment: ${ADJUSTMENT} dB"
    
    # 4. Apply & Register
    read -p "Confirm save as $KEY and update assets.json? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        local OUTPUT_FILENAME="optimized_${KEY}.mp3"
        local OUTPUT_PATH="$INPUT_DIR/$OUTPUT_FILENAME"
        
        echo "🚀 Normalizing and saving..."
        ffmpeg -y -i "$INPUT_FILE" -af "volume=${ADJUSTMENT}dB" "$OUTPUT_PATH"
        
        # Update assets.json
        jq --arg k "$KEY" --arg f "$OUTPUT_FILENAME" '.[$k] = $f' "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
        
        echo "✅ Saved as $OUTPUT_FILENAME and registered in assets.json!"
    else
        echo "❌ Operation cancelled."
    fi
}