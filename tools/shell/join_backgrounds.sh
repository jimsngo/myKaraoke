#!/bin/bash
# Library: join_backgrounds.sh
join_backgrounds() {
    echo "Select ONE background video file:"
    
    # AppleScript to select exactly one file
    local FILE=$(osascript -e 'return POSIX path of (choose file with prompt "Select background video:")')
    
    [[ -z "$FILE" ]] && return 1

    local OUTPUT_FILENAME="optimized_background.mp4"
    local OUTPUT_PATH="$INPUT_DIR/$OUTPUT_FILENAME"

    echo "🎬 Copying file for playback..."
    
    # Direct copy ensures no processing or container changes
    cp "$FILE" "$OUTPUT_PATH"

    # Register in assets.json
    read -p "Register '$OUTPUT_FILENAME' as background in assets.json? (Y/n): " confirm
    confirm=${confirm:-y} 

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        jq --arg f "$OUTPUT_FILENAME" '.background = $f' "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
        echo "✅ Background saved to '$OUTPUT_PATH' and registered."
    else
        echo "⏭️ Background saved to '$OUTPUT_PATH'."
    fi
}