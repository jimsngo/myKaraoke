#!/bin/bash
# Library: tools/shell/import_background.sh

import_background() {
    mkdir -p "$INPUT_DIR/Background"

    if [[ -f "$PRESETS" ]]; then
        local REL_AUDIO=$(jq -r '.inputs.main_audio // ""' "$PRESETS")
    fi

    if [[ -z "$REL_AUDIO" || ! -f "$PROJECT_DIR/$REL_AUDIO" ]]; then
        echo "❌ Error: No main audio file found registered in assets.json."
        echo "   Please run Option 2 (Import Audio) first so we can calculate durations!"
        return 1
    fi

    local ABS_AUDIO="$PROJECT_DIR/$REL_AUDIO"

    echo "🎬 Select ONE background video loop asset:"
    local FILE=$(osascript -e 'return POSIX path of (choose file with prompt "Select background video loop source:")' 2>/dev/null)
    
    [[ -z "$FILE" ]] && { echo "⏭️ Selection canceled."; return 1; }

    # 🛠️ FIXED: Strictly isolate the name of the SOURCE VIDEO asset used
    local BG_BASE=$(basename "$FILE")
    local BG_NAME="${BG_BASE%.*}" # Extracts "Yosemeti" from "Yosemeti.mp4"

    local ABS_OUTPUT_PATH="$INPUT_DIR/Background/${BG_NAME}_optimized_background.mp4"
    local REL_OUTPUT_PATH="inputs/Background/${BG_NAME}_optimized_background.mp4"

    echo ""
    echo "🖥️  Resolution Optimization Options:"
    echo "1) Force 1080p (Auto scale up/down with smart padding) [DEFAULT]"
    echo "2) Keep Original Resolution (Preserve native source dimensions)"
    read -p "Choose optimization profile [1-2, Enter for 1]: " res_choice
    res_choice=${res_choice:-1}

    local SCALE_FILTER=""
    local PRESET_PROFILE="veryfast"
    local CRF_PROFILE="24"

    if [[ "$res_choice" == "1" ]]; then
        SCALE_FILTER="-vf scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
        CRF_PROFILE="26"
        echo "⚡ Profile Selected: Conforming source canvas to standard 1080p layout."
    else
        SCALE_FILTER=""
        CRF_PROFILE="22"
        echo "💎 Profile Selected: Preserving original raw source format layout boundaries."
    fi
    echo ""

    echo "⏳ Calculating length of reference audio track..."
    local AUDIO_LEN=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_AUDIO")
    
    echo "⚙️  Pre-rendering background loop to cover total duration (${AUDIO_LEN}s)..."
    echo "🎥 Processing via FFmpeg..."
    
    ffmpeg -y -stream_loop -1 -i "$FILE" -t "$AUDIO_LEN" \
        $SCALE_FILTER \
        -c:v libx264 \
        -preset "$PRESET_PROFILE" \
        -crf "$CRF_PROFILE" \
        -pix_fmt yuv420p \
        -an "$ABS_OUTPUT_PATH"

    if [ $? -eq 0 ] && [ -f "$ABS_OUTPUT_PATH" ]; then
        echo ""
        echo "✅ Success: Pre-lengthened video track generated!"
        echo "📁 Saved using Video Source Name: $REL_OUTPUT_PATH"
        
        read -p "Register this file as the active background loop in assets.json? (Y/n): " confirm
        confirm=${confirm:-y} 

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            jq --arg p "$REL_OUTPUT_PATH" '.inputs.background = $p' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
            
            if type load_assets &>/dev/null; then load_assets; fi
            echo "💾 Registered to configuration matrix: '$REL_OUTPUT_PATH'"
        else
            echo "⏭️  File saved to folder, but assets.json remains unchanged."
        fi
    else
        echo "❌ Error: FFmpeg background processing layer failed."
        return 1
    fi
}