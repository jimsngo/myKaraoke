#!/bin/bash
# Library: import_subtitles.sh

import_subtitles() {
    # 1. Use your centralized file picker with the correct type
    local FILE=$(pick_file "Select your .ass subtitle file:" "ass")
    
    # 2. If a file was selected
    if [[ -n "$FILE" ]]; then
        local FILENAME=$(basename "$FILE")
        
        # 3. Copy using the global INPUT_DIR
        cp "$FILE" "$INPUT_DIR/$FILENAME"
        
        # 4. Use surgical jq update (don't overwrite the whole file)
        jq --arg f "$FILENAME" '.subtitles = $f' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
        
        # 5. Refresh the dashboard globals
        load_assets
        
        echo "✅ Subtitles registered: $FILENAME"
    else
        echo "⏭️ Import canceled."
    fi
}