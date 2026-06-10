#!/bin/bash
# Library: tools/shell/view_dashboard.sh

open_preview_room() {
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local PRESETS="$PROJECT_DIR/assets.json"

    echo "🌐 Project Session Initialization Module"
    echo "========================================================="
    read -p "Do you want to initialize/update a song track session? (y/N): " init_choice

    if [[ "$init_choice" =~ ^[Yy]$ ]]; then
        read -p "✍️ Enter Song Title (for Display Banner): " NEW_TITLE
        read -p "✍️ Enter Song Author/Artist: " NEW_AUTHOR

        if [[ -z "$NEW_TITLE" ]]; then
            echo "❌ Error: Song title cannot be blank. Initialization aborted."
            return 1
        fi

        echo "📂 Select the clean Master Mixed Audio Track file from Logic Pro..."
        local CHOSEN_FILE=$(pick_file "Select your Master Mixed Audio file" "mp3,wav,m4a")

        if [[ -z "$CHOSEN_FILE" ]] || [[ ! -f "$CHOSEN_FILE" ]]; then
            echo "❌ Error: Cancelled or invalid file path selected."
            return 1
        fi

        # Get the literal file name exactly as you generated it in Logic Pro
        local RAW_FILE_NAME=$(basename "$CHOSEN_FILE")
        local FILE_BASE="${RAW_FILE_NAME%.*}"
        
        # FIXED: Only strips the trailing mixed marker. NO lowercase conversion, NO character stripping.
        # This turns "Di-Vang-Nhat-Nhoa-Male-mixed" straight into "Di-Vang-Nhat-Nhoa-Male"
        local CLEAN_BASE=$(echo "$FILE_BASE" | sed 's/[-_][Mm]ixed//g')
        
        # Append the unified lowercase tracking suffix to your beautiful base name
        local NEW_FILE_NAME="${CLEAN_BASE}_mixed.mp3"
        local REL_MIXED_PATH="inputs/mixed_audio/$NEW_FILE_NAME"

        echo "🚚 Registering assets and organizing project workspace folders..."
        mkdir -p "$PROJECT_DIR/inputs/mixed_audio"
        
        # FIX: Force remove any old matching file first to clear case-insensitive locks
        rm -f "$PROJECT_DIR/$REL_MIXED_PATH"
        
        # Copy the fresh file with your perfect, unaltered casing
        cp "$CHOSEN_FILE" "$PROJECT_DIR/$REL_MIXED_PATH"

        if [[ $? -eq 0 ]]; then
            local TEMP_JSON=$(mktemp)
            jq --arg t "$NEW_TITLE" --arg a "$NEW_AUTHOR" --arg m "$REL_MIXED_PATH" \
               '.inputs.song_title = $t | .inputs.song_author = $a | .inputs.mixed_audio = $m' \
               "$PRESETS" > "$TEMP_JSON" && mv "$TEMP_JSON" "$PRESETS"
            echo "✅ Session successfully registered inside assets.json database!"
        else
            echo "❌ Error: Failed to copy audio track to project directory workspace."
            return 1
        fi
    fi

    # --- Live Preview Room Launch Sequence ---
    echo -e "\n🌐 Launching Local Browser Sync Control Station..."
    cd "$PROJECT_DIR" || return

    if nc -z localhost 5500 2>/dev/null; then
        echo "🔌 Detected active VS Code Live Server on Port 5500."
        open "http://localhost:5500/index.html"
        return 0
    fi

    if nc -z localhost 8000 2>/dev/null; then
        echo "🔌 Detected active Web Server running on Port 8000."
        open "http://localhost:8000/index.html"
        return 0
    fi

    echo "⚡ No active server detected. Initializing temporary background engine..."
    python3 -m http.server 8000 > /dev/null 2>&1 &
    local SERVER_PID=$!
    sleep 0.5
    
    echo "✅ Temporary background server online on Port 8000."
    open "http://localhost:8000/index.html"
    (sleep 1 && disown $SERVER_PID) 2>/dev/null
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    open_preview_room
fi