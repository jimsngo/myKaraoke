#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 5 Module
# Script: tools/shell/compile_synthv.sh
# Purpose: Compiles SynthV MIDI files straight into a raw .srt timing track.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ mixed_audio, source_midi, subtitles_srt ]
# ==============================================================================

compile_midi_subtitles() {
    # --- Local Environment Variables Block ---
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local PRESETS="$PROJECT_DIR/assets.json"
    local MIDI_DIR="$PROJECT_DIR/inputs/midi"
    local SUB_DIR="$PROJECT_DIR/inputs/subtitles"
    local JSON_GUARD="$PROJECT_DIR/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Mandating short-name srt key layout
    local REQUIRED_ASSET_KEYS=(
        "mixed_audio"
        "source_midi"
        "subtitles_srt"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active File Extraction & Processing Runs Safely Below ---
    local REL_MIXED=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")
    if [[ -z "$REL_MIXED" ]]; then
        echo "❌ Error: No active audio session found initialized. Please run Option 1 first!"
        return 1
    fi

    local MIXED_FILE_NAME=$(basename "$REL_MIXED")
    local TRACK_NAME="${MIXED_FILE_NAME%_mixed.*}"
    local REL_MIDI="inputs/midi/${TRACK_NAME}.mid"
    local ABS_MIDI="$PROJECT_DIR/$REL_MIDI"

    echo "📝 Synth V MIDI Subtitle Compiler Engine"
    echo "🎵 Active Session Base Name: $TRACK_NAME"
    echo "========================================================="

    local USE_EXISTING=false
    
    if [[ -s "$ABS_MIDI" ]]; then
        echo "📂 Found existing local MIDI asset in workspace:"
        echo "   👉 $REL_MIDI"
        echo "--------------------------------------------------------="
        echo -n "❓ Use this existing file? [Y/n] (Press Enter for Yes): "
        read -r choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [[ -z "$choice" || "$choice" == "y" || "$choice" == "yes" ]]; then
            USE_EXISTING=true
        fi
    fi

    if [ "$USE_EXISTING" = false ]; then
        echo "📂 Opening dialog. Select your source Synth V exported MIDI file..."
        local CHOSEN_MIDI=$(pick_file "Select your Synth V MIDI track" "mid,midi")

        if [[ -z "$CHOSEN_MIDI" || ! -f "$CHOSEN_MIDI" ]]; then
            echo "❌ Error: Cancelled or invalid MIDI file path selected."
            return 1
        fi

        echo "🚚 Saving raw MIDI asset into inputs/midi workspace..."
        mkdir -p "$MIDI_DIR"
        rm -f "$ABS_MIDI"
        cp "$CHOSEN_MIDI" "$ABS_MIDI" 2>/dev/null

        if [[ ! -s "$ABS_MIDI" ]]; then
            echo "❌ Error: Selected file is empty or unreadable."
            rm -f "$ABS_MIDI"
            return 1
        fi
    else
        echo "⚡ Reusing local workspace file: $REL_MIDI"
    fi

    mkdir -p "$SUB_DIR"
    # Keeping output short and matching your timing file extension choice
    local REL_SRT="inputs/subtitles/${TRACK_NAME}_synthv.srt"
    local ABS_SRT="$PROJECT_DIR/$REL_SRT"

    local PYTHON_SCRIPT="$PROJECT_DIR/tools/python/midi_to_ass.py"

    if [[ -f "$PYTHON_SCRIPT" ]]; then
        echo "⚙️ Processing musical note timings via local mido engine..."
        echo "--------------------------------------------------------="
        # Note: If your midi_to_ass.py still only exports .ass syntax internally, 
        # this will write that subtitle data smoothly straight into your .srt file name boundary!
        python3 "$PYTHON_SCRIPT" "$ABS_MIDI" "$ABS_SRT"
        local PARSE_STATUS=$?
        echo "--------------------------------------------------------="
    else
        echo "❌ Error: Core processing script missing at $PYTHON_SCRIPT"
        return 1
    fi

    if [[ $PARSE_STATUS -eq 0 ]]; then
        local temp_json=$(mktemp)
        # Register the short subtitles_srt key while cleaning up older legacy test keys
        jq --arg midi "$REL_MIDI" --arg srt "$REL_SRT" \
           '.inputs.source_midi = $midi | .inputs.subtitles_srt = $s_srt | del(.inputs.subtitles_srt_synthv) | del(.inputs.subtitles_raw_ass)' \
           "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
           
        echo "✅ Raw Subtitle timing track compiled successfully!"
        echo "📝 Registered [inputs.subtitles_srt]: $REL_SRT"
        return 0
    else
        echo "❌ Error: Python processing script failed."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    compile_midi_subtitles
fi