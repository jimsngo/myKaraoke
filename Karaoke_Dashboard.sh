#!/bin/bash
PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"
OUTPUT_DIR="$PROJECT_DIR/outputs"
PRESETS="$PROJECT_DIR/assets.json"

# Source Sourced Helper Modules (Shared Environment)
source "$PROJECT_DIR/tools/shell/ui_lib.sh"
source "$PROJECT_DIR/tools/shell/demucs_split.sh"
source "$PROJECT_DIR/tools/shell/optimized_volume.sh"
source "$PROJECT_DIR/tools/shell/strip_audio.sh"
source "$PROJECT_DIR/tools/shell/import_background.sh"

# --- Global Load Function ---
load_assets() {
    export MAIN_AUDIO=$(jq -r '.inputs.main_audio // ""' "$PRESETS")
    export INSTRUMENTS_ONLY=$(jq -r '.inputs.instruments_only // ""' "$PRESETS")
    export VOCALS_ONLY=$(jq -r '.inputs.vocals_only // ""' "$PRESETS")
    export SUBTITLES_SRT=$(jq -r '.inputs.subtitles_srt // ""' "$PRESETS")
    export SUBTITLES_ASS=$(jq -r '.inputs.subtitles_ass // ""' "$PRESETS")
    export BACKGROUND=$(jq -r '.inputs.background // ""' "$PRESETS")
}
load_assets

# --- Global File Picker Function ---
pick_file() {
    local prompt="$1"
    local extensions="$2"
    local apple_types=$(echo "$extensions" | sed 's/,/", "/g' | sed 's/^/{"/' | sed 's/$/"}/')
    osascript -e "return POSIX path of (choose file with prompt \"$prompt\" of type $apple_types)" 2>/dev/null
}

# --- Import Production ASS Subtitles (Option 6) ---
import_ass_subtitles() {
    local FILE=$(pick_file "Select your production .ass subtitle file:" "ass")
    if [[ -n "$FILE" ]]; then
        local FILENAME=$(basename "$FILE")
        mkdir -p "$INPUT_DIR/Subtitles"
        
        local TARGET_SUB="$INPUT_DIR/Subtitles/$FILENAME"
        cp "$FILE" "$TARGET_SUB"
        
        local REL_SUB="inputs/Subtitles/$FILENAME"
        jq --arg p "$REL_SUB" '.inputs.subtitles_ass = $p' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
        
        load_assets
        echo "✅ Production ASS Subtitles registered: $REL_SUB"
    else
        echo "⏭️ Import canceled."
    fi
}

while true; do
    display_menu
    read -p "Select [1-11] or press Enter to exit: " choice
    
    if [[ -z "$choice" ]]; then
        echo "👋 Exiting..."
        exit 0
    fi

    case $choice in
        1) demucs_split; read -p "Press Enter..." ;;
        2) optimize_volume; read -p "Press Enter..." ;;
        3) strip_audio; read -p "Press Enter..." ;;
        4) import_background; read -p "Press Enter..." ;;
        5) 
            bash "$PROJECT_DIR/tools/shell/auto_caption_whisper.sh"
            read -p "Press Enter..." 
            ;;
        6) 
            import_ass_subtitles
            read -p "Press Enter..." 
            ;;
        7) bash "$PROJECT_DIR/view_dashboard.sh" ;;
        8) bash "$PROJECT_DIR/tools/shell/create_video.sh"; read -p "Press Enter..." ;;
        9) bash "$PROJECT_DIR/tools/shell/create_lyrics_video.sh"; read -p "Press Enter..." ;;
        10) rm -rf "$OUTPUT_DIR/Karaoke"/* "$OUTPUT_DIR/Lyrics"/*; echo "✅ Outputs cleanly purged."; read -p "Press Enter..." ;;
        11) cd "$PROJECT_DIR"; git add .; git commit -m "Update"; git push origin main; read -p "Press Enter..." ;;
        *) echo "Invalid choice"; read -p "Press Enter..." ;;
    esac
done