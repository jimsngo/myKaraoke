#!/bin/bash
# ==============================================================================
# ⚠️ WARNING: NEVER DELETE OR MODIFY THIS SUMMARY BLOCK. ALL DIRECTIONS MUST BE FOLLOWED.
# ⚠️ DIRECTIVE: FOLLOW THE assets.json CONFIGURATION WITH ABSOLUTE FIDELITY. NO DEVIATIONS.
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Central Management Dashboard Router
# Script: Karaoke_Dashboard.sh
#
# Reference Blueprint Mapping (From assets.json -> dashboard_routing):
#   Option 1  -> tools/shell/view_dashboard.sh        (open_preview_room)
#   Option 2  -> tools/shell/ingest_stems_engine.sh   (ingest_stems_engine)
#   Option 3  -> tools/shell/optimized_volume.sh      (optimize_volume)
#   Option 4  -> tools/shell/auto_caption_whisper.sh  (auto_caption_whisper)
#   Option 5  -> tools/shell/compile_synthv.sh        (compile_midi_subtitles -> midi_to_ass.py)
#   Option 6  -> tools/shell/import_production_ass.sh (import_ass_subtitles)
#   Option 7  -> tools/shell/strip_audio.sh           (strip_audio)
#   Option 8  -> tools/shell/import_background.sh     (import_background)
#   Option 9  -> tools/shell/create_video.sh          (create_karaoke_video)
#   Option 10 -> tools/shell/create_lyrics_video.sh   (create_lyrics_video)
#   Option 11 -> tools/shell/purge_outputs.sh         (purge_outputs)
#   Option 12 -> tools/shell/git_sync.sh              (git_sync)
#   Option 13 -> tools/shell/validate_assets.sh       (validate_project_assets)
#
# Guardrails:
#   1. This script must strictly remain under 50 lines for fast scanning.
#   2. Zero inline logic allowed. All tasks must route to external subscripts.
# ==============================================================================

PROJECT_DIR="/Users/jim/myKaraoke"

# Path to your assets
ASSETS_FILE="assets.json"

# Explicitly map JSON keys to your preferred, readable variable names
export SONG_TITLE=$(jq -r '.inputs.song_title' "$ASSETS_FILE")
export SONG_AUTHOR=$(jq -r '.inputs.song_author' "$ASSETS_FILE")
# Audio paths
export MIXED_AUDIO=$(jq -r '.inputs.mixed_audio' "$ASSETS_FILE")
export INSTRUMENTS_ONLY=$(jq -r '.inputs.instruments_only' "$ASSETS_FILE")
export VOCALS_ONLY=$(jq -r '.inputs.vocals_only' "$ASSETS_FILE")
# MIDI paths
export MIDI_FILE=$(jq -r '.inputs.source_midi' "$ASSETS_FILE")  
export MIDI_BPM=$(jq -r '.inputs.bpm' "$ASSETS_FILE")
export MIDI_KEY=$(jq -r '.inputs.midi_key' "$ASSETS_FILE")
export SECONDS_PER_BEAT=$(jq -r '.inputs.seconds_per_beat' "$ASSETS_FILE")
# Subtitle paths
export SUBTITLES_TXT=$(jq -r '.inputs.subtitles_txt' "$ASSETS_FILE")
export SUBTITLES_ASS=$(jq -r '.inputs.subtitles_ass' "$ASSETS_FILE")
# Video paths
export BACKGROUND_VID=$(jq -r '.inputs.background' "$ASSETS_FILE")

# Source the centralized UI menu renderer
source "$PROJECT_DIR/tools/shell/ui_lib.sh" || exit 1

while true; do
    display_menu
    echo -n -e "👉 Select option [0-13] (or hit Enter to re-display menu): "
    read -r choice

    if [[ -z "$choice" ]]; then
        REFRESH_MENU=true
        continue
    fi

    # 🛠️ VISUAL SEPARATION BLOCK: Displays the active execution status row cleanly
    echo -e "\n⚡ Executing option [$choice] from assets.json blueprint..."
    
    # Dynamically extract script details, functions, and dependency notes from assets.json
    SCRIPT_PATH=$(jq -r ".dashboard_routing.\"$choice\".script // \"\"" "$PROJECT_DIR/assets.json")
    FUNC_NAME=$(jq -r ".dashboard_routing.\"$choice\".function // \"\"" "$PROJECT_DIR/assets.json")
    ROUTING_NOTE=$(jq -r ".dashboard_routing.\"$choice\".note // \"\"" "$PROJECT_DIR/assets.json")

    if [[ -n "$ROUTING_NOTE" && "$ROUTING_NOTE" != "null" ]]; then
        echo -e "📝 Dependent Script Note: $ROUTING_NOTE\n"
    fi

    if [[ "$choice" == "0" ]]; then
        echo "👋 Exiting myKaraoke control room. Keep creating!"
        exit 0
    elif [[ -n "$SCRIPT_PATH" && -f "$PROJECT_DIR/$SCRIPT_PATH" ]]; then
        source "$PROJECT_DIR/$SCRIPT_PATH"
        $FUNC_NAME
    else
        echo "❌ Invalid selection or target library script missing for option [$choice]."
    fi

    echo ""
    read -p "Press [Enter] to return to the master dashboard menu..."
done