#!/bin/bash
# Library: join_backgrounds.sh
join_backgrounds() {
    echo "Select background video files to join (Hold CMD for multiple):"
    
    # Using a much simpler AppleScript call that doesn't use 'text item delimiters'
    # This just returns the list of files to the shell, which handles the spaces.
    local FILES=$(osascript -e '
        set fileList to choose file with prompt "Select background videos:" with multiple selections allowed
        set posixPaths to ""
        repeat with f in fileList
            set posixPaths to posixPaths & POSIX path of f & "\n"
        end repeat
        return posixPaths
    ')
    
    [[ -z "$FILES" ]] && return 1

    # Format for FFmpeg's concat
    echo "$FILES" | sed "s/^/file '/;s/$/'/" > inputs.txt
    
    local OUTPUT_FILENAME="optimized_background.mp4"
    local OUTPUT_PATH="$INPUT_DIR/$OUTPUT_FILENAME"

    echo "🎬 Joining videos..."
    ffmpeg -y -f concat -safe 0 -i inputs.txt -c copy "$OUTPUT_PATH"
    rm inputs.txt

    # Register in assets.json
    read -p "Register '$OUTPUT_FILENAME' as background in assets.json? (Y/n): " confirm
    confirm=${confirm:-y} 

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        jq --arg f "$OUTPUT_FILENAME" '.background = $f' "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
        echo "✅ Background saved to '$OUTPUT_PATH' and registered."
    else
        echo "✅ Background saved to '$OUTPUT_PATH' (Not registered)."
    fi
}