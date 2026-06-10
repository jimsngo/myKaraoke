#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 6 Module
# Script: tools/shell/import_production_ass.sh
# Purpose: Imports curated Aegisub stylized subtitles into production tracking.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ subtitles_ass ]
# ==============================================================================

import_ass_subtitles() {
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local INPUT_DIR="$PROJECT_DIR/inputs"
    local PRESETS="$PROJECT_DIR/assets.json"
    local JSON_GUARD="$PROJECT_DIR/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Monitor short-name production key mapping
    local REQUIRED_ASSET_KEYS=(
        "subtitles_ass"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active Production Import Processing Runs Safely Below ---
    local REL_MIXED=$(jq -r '.inputs.mixed_audio // ""' "$PRESETS")
    local TRACK_NAME=""
    if [[ -n "$REL_MIXED" ]]; then
        local MIXED_FILE_NAME=$(basename "$REL_MIXED")
        TRACK_NAME="${MIXED_FILE_NAME%_mixed.*}"
    fi

    echo "🎬 Select your master production .ass subtitle file from Aegisub:"
    local FILE=$(pick_file "Select your production .ass subtitle file" "ass")
    
    if [[ -n "$FILE" && -f "$FILE" ]]; then
        local FINAL_FILENAME
        if [[ -n "$TRACK_NAME" ]]; then
            FINAL_FILENAME="${TRACK_NAME}_production.ass"
        else
            FINAL_FILENAME=$(basename "$FILE")
        fi
        
        local TARGET_DIR="$INPUT_DIR/subtitles"
        mkdir -p "$TARGET_DIR"
        
        local TARGET_SUB="$TARGET_DIR/$FINAL_FILENAME"
        local REL_SUB="inputs/subtitles/$FINAL_FILENAME"
        
        echo "🚚 Copying file to local project assets layout..."
        rm -f "$TARGET_SUB"
        cp "$FILE" "$TARGET_SUB"
        
        if [[ $? -eq 0 && -f "$TARGET_SUB" ]]; then
            local temp_json=$(mktemp)
            # Register cleanly under the concise subtitles_ass key while dropping any legacy experiments
            jq --arg p "$REL_SUB" '.inputs.subtitles_ass = $p | del(.inputs.subtitles_production_ass)' \
               "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
            
            echo "✅ Production ASS Subtitles registered successfully!"
            echo "📝 Registered [inputs.subtitles_ass]: $REL_SUB"
            return 0
        else
            echo "❌ Error: Failed to copy the subtitle file into the project directory."
            return 1
        fi
    else
        echo "⏭️  Import canceled."
        return 0
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    import_ass_subtitles
fi