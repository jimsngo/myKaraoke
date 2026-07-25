#!/bin/bash
# Library: tools/shell/asset_manager.sh
# Purpose: Validates, initializes, and safely copies external/cloud assets into the project sandbox

initialize_or_verify_session() {
    local PRESETS="$PROJECT_DIR/assets.json"
    clear
    echo "🔍 Verifying Current Active Asset Registry State..."
    echo "========================================================="
    
    if [[ -f "$PRESETS" ]]; then
        jq -r '.inputs | "🎵 Active Track: \(.song_title) (by \(.song_author))\n⏱️  Tempo Profile: \(.bpm) BPM (\(.seconds_per_beat) sec/beat)\n🎛️  Source Mix:  \(.mixed_audio)\n🎸 Instrumental: \(.instruments_only)\n🎹 Source MIDI:  \(.source_midi)\n🎥 Background:   \(.background)\n📝 Output ASS:   \(.subtitles_ass)"' "$PRESETS"
    else
        echo "⚠️  Warning: assets.json database file not detected!"
    fi
    echo "========================================================="
    echo "1) Proceed with current session configuration"
    echo "2) Initialize / Map a completely new song session"
    echo "3) Selectively update an asset path or project tempo"
    read -p "Select operational gate entry [1-3]: " gate_choice

    case "$gate_choice" in
        2) Run_Full_Asset_Ingestion ;;
        3) Run_Selective_Asset_Updater ;;
        *) echo "✅ Configuration locked. Loading utility suite..." ;;
    esac
}

# 🤖 THE AUTO-INGESTION ENGINE
handle_and_localize_asset() {
    local source_path="$1"
    local target_subfolder="$2"
    
    if [[ -z "$source_path" ]]; then
        echo ""
        return
    fi
    
    if [[ "$source_path" == "$PROJECT_DIR"/* ]]; then
        # Preserve paths inside the project as workspace-relative for portability (e.g., Colab).
        local rel_path="${source_path#"$PROJECT_DIR"/}"
        echo "$rel_path"
        return
    fi
    
    local filename=$(basename "$source_path")
    local target_dir="$PROJECT_DIR/$target_subfolder"
    mkdir -p "$target_dir"
    
    echo "📥 Localizing cloud asset: $filename -> $target_subfolder/" >&2
    cp "$source_path" "$target_dir/$filename"
    
    echo "$target_subfolder/$filename"
}

Run_Full_Asset_Ingestion() {
    local PRESETS="$PROJECT_DIR/assets.json"
    echo -e "\n📝 Setting up brand new song metadata entries..."
    read -p "Enter Song Title: " new_title
    read -p "Enter Song Author/Artist: " new_author
    read -p "Enter Song Tempo (BPM - e.g., 120 or 70): " new_bpm

    # 🧮 AUTOMATIC TEMPO MATH: Calculate seconds per beat using awk
    local NEW_SPB=$(awk "BEGIN {print 60 / $new_bpm}")

    echo "📂 Select your Master Mixed Audio track source file..."
    local CHOSEN_MIX=$(pick_file "Select your Master Mixed Audio File")
    local REL_MIX=$(handle_and_localize_asset "$CHOSEN_MIX" "inputs/mixed")

    echo "📂 Select your Aligned Instruments Only backing track file..."
    local CHOSEN_INST=$(pick_file "Select your Instruments Only File")
    local REL_INST=$(handle_and_localize_asset "$CHOSEN_INST" "inputs/instruments")
    
    echo "📂 Select your exported Logic Pro MIDI file..."
    local CHOSEN_MIDI=$(pick_file "Select your Track MIDI File")
    local REL_MIDI=$(handle_and_localize_asset "$CHOSEN_MIDI" "inputs/midi")

    echo "📂 Select your Production Background Scenery Video file..."
    local CHOSEN_BG=$(pick_file "Select your Background Scenery Video")
    local REL_BG=$(handle_and_localize_asset "$CHOSEN_BG" "inputs/background")

    # AUTOMATIC BASE NAME GENERATION FOR SUBTITLES
    local MIDI_BASE_NAME=$(basename "$CHOSEN_MIDI")
    local FILE_BASE="${MIDI_BASE_NAME%.*}"
    local NEW_SUB_ASS="inputs/subtitles/${FILE_BASE}.ass"

    # Commit entries live to the master JSON file and convert numerical parameters safely
    local temp_json=$(mktemp)
    jq --arg t "$new_title" --arg a "$new_author" --arg b "$new_bpm" --arg spb "$NEW_SPB" \
       --arg m "$REL_MIX" --arg i "$REL_INST" --arg d "$REL_MIDI" --arg b_vid "$REL_BG" --arg s "$NEW_SUB_ASS" \
       '.inputs.song_title = $t | .inputs.song_author = $a | .inputs.bpm = ($b | tonumber) | .inputs.seconds_per_beat = ($spb | tonumber) | .inputs.mixed_audio = $m | .inputs.instruments_only = $i | .inputs.source_midi = $d | .inputs.background = $b_vid | .inputs.subtitles_ass = $s | del(.inputs.subtitles_production_ass)' \
       "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
    
    echo -e "\n🎉 Asset Registry initialized successfully for: $new_title!"
}

Run_Selective_Asset_Updater() {
    local PRESETS="$PROJECT_DIR/assets.json"
    echo -e "\n🔧 Select the track registry value you need to fix:"
    echo "1) Update Mixed Audio Track Path"
    echo "2) Update Instruments Only Track Path"
    echo "3) Update MIDI File Path"
    echo "4) Update Background Video Path"
    echo "5) Adjust Song Tempo (BPM)"
    read -p "Selection [1-5]: " update_choice

    local temp_json=$(mktemp)
    if [[ "$update_choice" == "1" ]]; then
        local NEW_FILE=$(pick_file "Select local Master Mixed Audio file")
        local REL_FILE=$(handle_and_localize_asset "$NEW_FILE" "inputs/mixed")
        jq --arg p "$REL_FILE" '.inputs.mixed_audio = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "✅ Mixed Audio asset path updated and localized successfully."

    elif [[ "$update_choice" == "2" ]]; then
        local NEW_FILE=$(pick_file "Select local Instruments Only backing track")
        local REL_FILE=$(handle_and_localize_asset "$NEW_FILE" "inputs/instruments")
        jq --arg p "$REL_FILE" '.inputs.instruments_only = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "✅ Instruments Only track path updated and localized successfully."
        
    elif [[ "$update_choice" == "3" ]]; then
        local NEW_FILE=$(pick_file "Select new alignment MIDI file")
        local REL_FILE=$(handle_and_localize_asset "$NEW_FILE" "inputs/midi")
        
        local MIDI_BASE_NAME=$(basename "$NEW_FILE")
        local FILE_BASE="${MIDI_BASE_NAME%.*}"
        local NEW_SUB_ASS="inputs/subtitles/${FILE_BASE}.ass"

        jq --arg p "$REL_FILE" --arg s "$NEW_SUB_ASS" \
           '.inputs.source_midi = $p | .inputs.subtitles_ass = $s | del(.inputs.subtitles_production_ass)' \
           "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "✅ MIDI and Subtitle layout asset paths updated and localized successfully."
        
    elif [[ "$update_choice" == "4" ]]; then
        local NEW_FILE=$(pick_file "Select new scenery video file")
        local REL_FILE=$(handle_and_localize_asset "$NEW_FILE" "inputs/background")
        jq --arg p "$REL_FILE" '.inputs.background = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "✅ Background video path updated and localized successfully."

    elif [[ "$update_choice" == "5" ]]; then
        read -p "Enter correct track BPM: " adj_bpm
        local ADJ_SPB=$(awk "BEGIN {print 60 / $adj_bpm}")
        jq --arg b "$adj_bpm" --arg spb "$ADJ_SPB" '.inputs.bpm = ($b | tonumber) | .inputs.seconds_per_beat = ($spb | tonumber)' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
        echo "✅ Project tempo recalculated and synchronized successfully."
    fi
}