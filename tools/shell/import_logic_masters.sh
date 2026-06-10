#!/bin/bash
# Library: tools/shell/import_logic_masters.sh

import_logic_masters() {
    local PROJECT_ROOT="/Users/jim/myKaraoke"
    local PRESETS="$PROJECT_ROOT/assets.json"

    # Verify a session has been instantiated
    local RAW_TITLE=$(jq -r '.inputs.song_title // ""' "$PRESETS")
    if [[ -z "$RAW_TITLE" ]]; then
        echo "❌ Error: No active song session initialized. Please run Option 1 first!"
        return 1
    fi

    echo "🎛️  Logic Pro Production Master Importer Canvas Initialized..."
    echo "🎵 Active Session Context: $RAW_TITLE"
    echo "========================================================="
    echo "1) Import Instruments Only Stem   (replaces instruments_only)"
    echo "2) Import Vocals Only Stem        (replaces vocals_only)"
    echo "3) Cancel Import"
    read -p "Select asset target destination [1-3]: " target_choice

    local DB_KEY=""
    local DEST_DIR=""
    local FILE_SUFFIX=""

    case "$target_choice" in
        1) DB_KEY="instruments_only"; DEST_DIR="inputs/instruments"; FILE_SUFFIX="_instruments.mp3" ;;
        2) DB_KEY="vocals_only"; DEST_DIR="inputs/vocals"; FILE_SUFFIX="_vocals.mp3" ;;
        *) echo "⏭️  Import aborted."; return 0 ;;
    esac

    local CLEAN_TITLE=$(echo "$RAW_TITLE" | iconv -t ascii//TRANSLIT -c 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9 ' | tr ' ' '-')
    [[ -z "$CLEAN_TITLE" ]] && CLEAN_TITLE=$(echo "$RAW_TITLE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9 ' | tr ' ' '-')
    
    local NEW_FILE_NAME="${CLEAN_TITLE}${FILE_SUFFIX}"
    local TARGET_DESTINATION="${DEST_DIR}/${NEW_FILE_NAME}"

    echo "📂 Launching macOS File Selection Window..."
    local CHOSEN_FILE=$(pick_file "Select your Logic Pro Export file" "mp3,wav,m4a")

    if [[ -z "$CHOSEN_FILE" ]] || [[ ! -f "$CHOSEN_FILE" ]]; then
        echo "❌ Error: Cancelled or invalid file path selected."
        return 1
    fi

    echo "🚚 Processing tracking payload..."
    mkdir -p "$PROJECT_ROOT/$DEST_DIR"
    cp "$CHOSEN_FILE" "$PROJECT_ROOT/$TARGET_DESTINATION"

    if [[ $? -eq 0 ]]; then
        local TEMP_JSON=$(mktemp)
        jq ".inputs.${DB_KEY} = \"${TARGET_DESTINATION}\"" "$PRESETS" > "$TEMP_JSON" && mv "$TEMP_JSON" "$PRESETS"
        echo -e "✅ Successfully imported: \033[1;32m$NEW_FILE_NAME\033[0m"
        echo "📝 Database registration mapping key [.inputs.${DB_KEY}] updated flawlessly!"
    else
        echo "❌ Error: Failed to copy audio payload into destination directory tree."
    fi
}