#!/bin/bash
PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"

pick_file() {
    local prompt="$1"
    local ftypes="$2"
    osascript -e "POSIX path of (choose file with prompt \"$prompt\" of type {$ftypes})" 2>/dev/null
}

while true; do
    clear
    echo "----------------------------------------------------------------"
    echo "             ✝️  Karaoke_Dashboard v4.3 (Full Pipeline) ✝️      "
    echo "----------------------------------------------------------------"
    echo "Active Assets in /inputs:"
    ls -1 "$INPUT_DIR"
    echo "----------------------------------------------------------------"
    echo " 1) Import Assets"
    echo " 2) Create Karaoke Video (Instrumental)"
    echo " 3) Create Lyrics Video (Mixed)"
    echo " 4) Push Scripts to GitHub"
    echo " 5) Exit"
    echo "----------------------------------------------------------------"
    read -p "Select [1-5]: " CHOICE

    case $CHOICE in
        1)
            V=$(pick_file "Select Vocal" "\"mp3\", \"wav\"")
            I=$(pick_file "Select Instrumental" "\"mp3\", \"wav\"")
            M=$(pick_file "Select Mixed" "\"mp3\", \"wav\"")
            L=$(pick_file "Select Lyrics (.ass)" "\"ass\"")
            B=$(pick_file "Select Background" "\"jpg\", \"png\", \"mp4\", \"mov\"")
            
            [[ -n "$V" ]] && cp "$V" "$INPUT_DIR/"
            [[ -n "$I" ]] && cp "$I" "$INPUT_DIR/"
            [[ -n "$M" ]] && cp "$M" "$INPUT_DIR/"
            [[ -n "$L" ]] && cp "$L" "$INPUT_DIR/"
            [[ -n "$B" ]] && cp "$B" "$INPUT_DIR/"
            ;;
        2)
            INST=$(ls "$INPUT_DIR" | grep -Ei '\.(mp3|wav)$' | head -n 1)
            LYR=$(ls "$INPUT_DIR" | grep -Ei '\.ass$' | head -n 1)
            
            if [[ -z "$INST" || -z "$LYR" ]]; then
                echo "❌ Error: Missing instrumental or .ass file."
            else
                echo "🚀 Running production pipeline..."
                python3 color_karaoke.py "$INPUT_DIR/$LYR"
                ./create_video.sh "$INPUT_DIR/$INST" "$INPUT_DIR/$LYR"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        3) 
            echo "Lyrics rendering logic pending."
            read -p "Press Enter to return..." 
            ;;
        4) 
            cd "$PROJECT_DIR" && git add . && git commit -m "Auto-sync: $(date +'%Y-%m-%d %H:%M')" && git push origin main
            echo "✅ GitHub sync complete!"
            read -p "Press Enter to return..."
            ;;
        5) exit 0 ;;
    esac
done
