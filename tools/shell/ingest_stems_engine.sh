#!/bin/bash
# Unified Library: tools/shell/ingest_stems_engine.sh

ingest_stems_engine() {
# --- Local Environment Variables Block ---
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local INPUT_DIR="$PROJECT_DIR/inputs"
    local PRESETS="$PROJECT_DIR/assets.json"
    local JSON_GUARD="$PROJECT_DIR/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Declare the exact keys this script depends on to run
    local REQUIRED_ASSET_KEYS=(
        "mixed_audio"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # 1. Fetch the already initialized mixed_audio asset path directly from your database
    local REL_MIXED=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")
    local ABS_MIXED="$PROJECT_DIR/$REL_MIXED"
    
    if [[ -z "$REL_MIXED" ]] || [[ ! -f "$ABS_MIXED" ]]; then
        echo "❌ Error: No active mixed_audio session found registered. Please run Option 1 first!"
        return 1
    fi

    # Read the file name directly from Option 1, maintaining your capitalization style
    local MIXED_FILE_NAME=$(basename "$ABS_MIXED")
    local TRACK_NAME="${MIXED_FILE_NAME%_mixed.*}" 

    echo "🎼 Audio Stem Ingestion Engine"
    echo "🎵 Active Session Base Name: $TRACK_NAME"
    echo "========================================================="
    echo "1) Manual Import: Aligned Production Stems (Logic Pro Route)"
    echo "2) Automated Split: AI Separation Engine    (Demucs Route)"
    echo "3) Cancel"
    read -p "Select ingestion pipeline strategy [1-3]: " workflow_choice

    case "$workflow_choice" in
        1)
            # --- ROUTE 1: LOGIC PRO MASTER IMPORTS ---
            echo -e "\n🎛️  Logic Pro Import Assistant Initiated..."
            echo "1) Import Instruments Only Stem"
            echo "2) Import Vocals Only Stem"
            echo "3) Import BOTH Stems (Sequential Pickers)"
            read -p "Select import package target [1-3]: " logic_choice

            local IMPORT_INST=false
            local IMPORT_VOC=false
            [[ "$logic_choice" == "1" || "$logic_choice" == "3" ]] && IMPORT_INST=true
            [[ "$logic_choice" == "2" || "$logic_choice" == "3" ]] && IMPORT_VOC=true

            if [ "$IMPORT_INST" = true ]; then
                echo "📂 Select your pre-formatted Instruments backing track file..."
                local CHOSEN_INST=$(pick_file "Select your Aligned Instruments file" "mp3,wav,m4a")
                if [[ -n "$CHOSEN_INST" && -f "$CHOSEN_INST" ]]; then
                    local INST_EXT="${CHOSEN_INST##*.}"
                    local TARGET_INST="inputs/instruments/${TRACK_NAME}_instruments.${INST_EXT}"
                    
                    mkdir -p "$PROJECT_DIR/inputs/instruments"
                    cp "$CHOSEN_INST" "$PROJECT_DIR/$TARGET_INST"
                    
                    local temp_json=$(mktemp)
                    jq --arg path "$TARGET_INST" '.inputs.instruments_only = $path' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
                    echo "✅ Registered Instruments Stem: $TARGET_INST"
                else
                    echo "⚠️  Instruments import skipped or cancelled."
                fi
            fi

            if [ "$IMPORT_VOC" = true ]; then
                echo "📂 Select your pre-formatted isolated Vocals track file..."
                local CHOSEN_VOC=$(pick_file "Select your Aligned Vocals file" "mp3,wav,m4a")
                if [[ -n "$CHOSEN_VOC" && -f "$CHOSEN_VOC" ]]; then
                    local VOC_EXT="${CHOSEN_VOC##*.}"
                    local TARGET_VOC="inputs/vocals/${TRACK_NAME}_vocals.${VOC_EXT}"
                    
                    mkdir -p "$PROJECT_DIR/inputs/vocals"
                    cp "$CHOSEN_VOC" "$PROJECT_DIR/$TARGET_VOC"
                    
                    local temp_json=$(mktemp)
                    jq --arg path "$TARGET_VOC" '.inputs.vocals_only = $path' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
                    echo "✅ Registered Vocals Stem: $TARGET_VOC"
                else
                    echo "⚠️  Vocals import skipped or cancelled."
                fi
            fi
            ;;

        2)
            # --- ROUTE 2: AI DEMUCS SEPARATION ---
            local EXT="${MIXED_FILE_NAME##*.}"

            echo -e "\n🤖 Launching AI Demucs Split Engine..."
            echo "🎵 Processing Source Mix Matrix: $MIXED_FILE_NAME"
            
            mkdir -p "$INPUT_DIR/instruments" "$INPUT_DIR/vocals" "$INPUT_DIR/stems"

            if python3 -c "import sys, torch; sys.exit(0 if torch.backends.mps.is_available() else 1)" 2>/dev/null; then
                demucs --two-stems=vocals -n htdemucs --device mps "$ABS_MIXED" -o "$INPUT_DIR/stems"
            else
                demucs --two-stems=vocals -n htdemucs "$ABS_MIXED" -o "$INPUT_DIR/stems"
            fi

            if [[ $? -ne 0 ]]; then
                echo "❌ Error: AI Stem extraction processing step failed."
                return 1
            fi

            local DEMUCS_OUTPUT_DIR="$INPUT_DIR/stems/htdemucs/$TRACK_NAME"
            local FOUND_VOCALS=$(find "$DEMUCS_OUTPUT_DIR" -name "vocals.$EXT" | head -n 1)
            local FOUND_INST=$(find "$DEMUCS_OUTPUT_DIR" -name "no_vocals.$EXT" | head -n 1)

            if [[ -n "$FOUND_VOCALS" && -n "$FOUND_INST" ]]; then
                local FINAL_VOCALS_PATH="$INPUT_DIR/vocals/${TRACK_NAME}_vocals.$EXT"
                local FINAL_INST_PATH="$INPUT_DIR/instruments/${TRACK_NAME}_instruments.$EXT"
                
                mv "$FOUND_VOCALS" "$FINAL_VOCALS_PATH"
                mv "$FOUND_INST" "$FINAL_INST_PATH"
                rm -rf "$INPUT_DIR/stems"
                
                local REL_VOCALS="inputs/vocals/${TRACK_NAME}_vocals.$EXT"
                local REL_INST="inputs/instruments/${TRACK_NAME}_instruments.$EXT"
                
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
            ;;
            
        *)
            echo "⏭️  Operation aborted."
            return 0
            ;;
    esac
}