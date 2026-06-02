#!/bin/bash
# Library: import_assets.sh

import_assets() {
    echo "--- Incremental Asset Importer ---"
    
    # List of keys to check
    local ASSETS=("mixed_audio" "instruments_only" "subtitles" "background")
    
    for KEY in "${ASSETS[@]}"; do
        echo "Checking asset: [$KEY]..."
        
        # Open file picker, allow cancel
        local FILE=$(osascript -e "return POSIX path of (choose file with prompt 'Select file for $KEY (or Cancel to skip):')" 2>/dev/null || echo "")
        
        if [[ -n "$FILE" ]]; then
            local FILENAME=$(basename "$FILE")
            echo "✅ Importing $FILENAME for $KEY..."
            
            # Copy file
            cp "$FILE" "$INPUT_DIR/$FILENAME"
            
            # Update registry
            jq --arg k "$KEY" --arg f "$FILENAME" '.[$k] = $f' "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
        else
            echo "⏭️ Skipping $KEY."
        fi
    done
    
    echo "--- Import complete. Assets updated. ---"
}