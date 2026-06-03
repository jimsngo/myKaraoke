#!/bin/bash
PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"
OUTPUT_DIR="$PROJECT_DIR/outputs"
PRESETS="$PROJECT_DIR/assets.json"

# Source Libraries
source "$PROJECT_DIR/tools/shell/ui_lib.sh"
source "$PROJECT_DIR/tools/shell/demucs_split.sh"
source "$PROJECT_DIR/tools/shell/optimized_volume.sh"
source "$PROJECT_DIR/tools/shell/strip_audio.sh"
source "$PROJECT_DIR/tools/shell/join_backgrounds.sh"

# --- Global Load Function ---
load_assets() {
    export MIXED_AUDIO=$(jq -r '.mixed_audio // ""' "$PRESETS")
    export INSTRUMENTS_ONLY=$(jq -r '.instruments_only // ""' "$PRESETS")
    export VOCALS_ONLY=$(jq -r '.vocals_only // ""' "$PRESETS")
    export SUBTITLES=$(jq -r '.subtitles // ""' "$PRESETS")
    export BACKGROUND=$(jq -r '.background // ""' "$PRESETS")
}
load_assets

# --- Global File Picker Function ---
pick_file() {
    local prompt="$1"
    local extensions="$2"
    local apple_types=$(echo "$extensions" | sed 's/,/", "/g' | sed 's/^/{"/' | sed 's/$/"}/')
    osascript -e "return POSIX path of (choose file with prompt \"$prompt\" of type $apple_types)" 2>/dev/null
}

# --- Global Subtitle Import Function ---
import_subtitles() {
    local FILE=$(pick_file "Select your .ass subtitle file:" "ass")
    if [[ -n "$FILE" ]]; then
        local FILENAME=$(basename "$FILE")
        cp "$FILE" "$INPUT_DIR/$FILENAME"
        jq --arg f "$FILENAME" '.subtitles = $f' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
        load_assets
        echo "✅ Subtitles registered: $FILENAME"
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
        4) join_backgrounds; read -p "Press Enter..." ;;
        5) import_subtitles; read -p "Press Enter..." ;;
        7) bash "$PROJECT_DIR/tools/shell/create_video.sh"; read -p "Press Enter..." ;;
        8) echo "Lyrics pending"; read -p "Press Enter..." ;;
        9) rm -f "$OUTPUT_DIR"/*; echo "✅ Outputs purged."; read -p "Press Enter..." ;;
        10) cd "$PROJECT_DIR"; git add .; git commit -m "Update"; git push origin main; read -p "Press Enter..." ;;
        11) exit 0 ;;
        *) echo "Invalid choice"; read -p "Press Enter..." ;;
    esac
done