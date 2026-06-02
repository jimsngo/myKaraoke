#!/bin/bash
PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"
OUTPUT_DIR="$PROJECT_DIR/outputs"
PRESETS="$PROJECT_DIR/assets.json"

source "$PROJECT_DIR/tools/shell/ui_lib.sh"
source "$PROJECT_DIR/tools/shell/demucs_split.sh"
source "$PROJECT_DIR/tools/shell/optimized_volume.sh"
source "$PROJECT_DIR/tools/shell/strip_audio.sh"
source "$PROJECT_DIR/tools/shell/join_backgrounds.sh"

pick_file() { osascript -e "POSIX path of (choose file with prompt \"$1\" of type {$2})" 2>/dev/null; }

while true; do
    display_menu
    # Updated prompt
    read -p "Select [1-11] or press Enter to exit: " choice
    
    # Exit if Enter is pressed (empty input)
    if [[ -z "$choice" ]]; then
        echo "👋 Exiting..."
        exit 0
    fi

    case $choice in
        # --- Media Tools ---
        1) demucs_split; read -p "Press Enter..." ;;
        2) optimize_volume; read -p "Press Enter..." ;;
        3) strip_audio; read -p "Press Enter..." ;;
        4) join_backgrounds; read -p "Press Enter..." ;;
        
        # --- Karaoke Tools ---
        6) # Import Assets
           rm -f "$INPUT_DIR"/*
           I=$(pick_file "Select Instrumental" "\"mp3\", \"wav\"")
           L=$(pick_file "Select Lyrics (.ass)" "\"ass\"")
           B=$(pick_file "Select Background" "\"mp4\", \"mov\"")
           
           jq --arg i "$(basename "$I")" --arg l "$(basename "$L")" --arg b "$(basename "$B")" \
           '{instrumental: $i, lyrics: $l, background: $b}' \
           "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
           
           [[ -n "$I" ]] && cp "$I" "$INPUT_DIR/"
           [[ -n "$L" ]] && cp "$L" "$INPUT_DIR/"
           [[ -n "$B" ]] && cp "$B" "$INPUT_DIR/"
           echo "✅ Assets imported."
           read -p "Press Enter..." ;;
        7) 
    # Ensure variables are fully expanded to absolute paths before passing
    INST="$INPUT_DIR/$(jq -r '.instruments_only' "$PRESETS")"
    LYR="$INPUT_DIR/$(jq -r '.subtitles' "$PRESETS")"
    BG="$INPUT_DIR/$(jq -r '.background' "$PRESETS")"
    
    # Pass them as absolute paths to the script
    "$PROJECT_DIR/tools/shell/create_video.sh" "$INST" "$LYR" "$BG"
    read -p "Press Enter to return..." ;;
        8) echo "Lyrics pending"; read -p "Press Enter..." ;;
        
        # --- System/Admin ---
        9) rm -f "$OUTPUT_DIR"/*; echo "✅ Outputs purged."; read -p "Press Enter..." ;;
        10) cd "$PROJECT_DIR"; git add .; git commit -m "Update"; git push origin main; read -p "Press Enter..." ;;
        11) exit 0 ;;
        *) echo "Invalid choice"; read -p "Press Enter..." ;;
    esac
done