#!/bin/bash
demucs_split() {
    local INPUT_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select song to split:")' 2>/dev/null)
    [[ -z "$INPUT_FILE" ]] && return 1

    local STEMS_DIR="$INPUT_DIR/stems"
    rm -rf "$STEMS_DIR"/*
    
    echo "🎵 Splitting stems with Demucs (Manual CLI)..."
    
    # We call 'demucs' as a direct binary instead of 'python3 -m demucs.separate'
    # This often bypasses the 'runpy' module's dependency checks.
    demucs --two-stems=vocals -n htdemucs "$INPUT_FILE" -o "$STEMS_DIR"
    
    # Check if files were created
    local VOCALS=$(find "$STEMS_DIR" -name "vocals.wav" | head -n 1)
    local INST=$(find "$STEMS_DIR" -name "no_vocals.wav" | head -n 1)

    if [[ -f "$VOCALS" && -f "$INST" ]]; then
        mv "$VOCALS" "$STEMS_DIR/vocals.wav"
        mv "$INST" "$STEMS_DIR/no_vocals.wav"
        jq --arg v "vocals.wav" --arg i "no_vocals.wav" '.vocals = $v | .instrumental = $i' "$PRESETS" > tmp.json && mv tmp.json "$PRESETS"
        echo "✅ Stems ready and registered."
    else
        echo "⚠️ Files not created. Check terminal output for errors."
    fi
}