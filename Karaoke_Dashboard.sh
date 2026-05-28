#!/bin/bash
PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"
OUTPUT_DIR="$PROJECT_DIR/outputs"
# Updated to use your new flat structure file
PRESETS="$PROJECT_DIR/assets.json"

# Load Logic Libraries
source "$PROJECT_DIR/tools/shell/ui_lib.sh"

pick_file() { osascript -e "POSIX path of (choose file with prompt \"$1\" of type {$2})" 2>/dev/null; }

while true; do
    display_menu
    read -p "Select [1-11]: " choice
    case $choice in
        1)
            # Cleanup inputs to ensure only active assets are present
            rm -f "$INPUT_DIR"/*
            
            # Select Assets
            I=$(pick_file "Select Instrumental" "\"mp3\", \"wav\"")
            L=$(pick_file "Select Lyrics (.ass)" "\"ass\"")
            B=$(pick_file "Select Background" "\"mp4\", \"mov\"")
            
            # Update assets.json with flat structure
            jq --arg i "$(basename "$I")" --arg l "$(basename "$L")" --arg b "$(basename "$B")" \
            '{instrumental: $i, lyrics: $l, background: $b}' \
            "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
            
            [[ -n "$I" ]] && cp "$I" "$INPUT_DIR/"
            [[ -n "$L" ]] && cp "$L" "$INPUT_DIR/"
            [[ -n "$B" ]] && cp "$B" "$INPUT_DIR/"
            echo "✅ Assets imported."
            read -p "Press Enter..." ;;
        2)
            # Classic Render: Read directly from assets.json
            INST="$INPUT_DIR/$(jq -r '.instrumental' "$PRESETS")"
            LYR="$INPUT_DIR/$(jq -r '.lyrics' "$PRESETS")"
            BG="$INPUT_DIR/$(jq -r '.background' "$PRESETS")"
            
            "$PROJECT_DIR/tools/shell/create_video.sh" "$INST" "$LYR" "$BG"
            read -p "Press Enter to return..." ;;
        3) echo "Lyrics pending"; read -p "Press Enter..." ;;
        4) 
            echo "🚀 Pushing to GitHub..."
            cd "$PROJECT_DIR"
            git add .
            git commit -m "Saving stable version v4.6"
            git push origin main
            echo "✅ Successfully pushed to GitHub."
            read -p "Press Enter..." ;;
        5) true ;;
        6) maximize_volume_all; read -p "Press Enter..." ;;
        7) scan_loudness_all; read -p "Press Enter..." ;;
        8) strip_audio_all; read -p "Press Enter..." ;;
        9) overlay_pulse; read -p "Press Enter..." ;;
        10) exit 0 ;;
        11) rm -f "$OUTPUT_DIR"/*; echo "✅ Outputs purged."; read -p "Press Enter..." ;;
        *) echo "Invalid choice"; read -p "Press Enter..." ;;
    esac
done