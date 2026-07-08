#!/bin/bash
# ==============================================================================
# 🎼 myKaraoke Project Toolchain — Option 14 Module
# Script: tools/shell/export_musescore_xml.sh
# Purpose: Convert Logic MIDI into a MuseScore-friendly sanitized MIDI.
# ============================================================================== 

PROJECT_DIR="${PROJECT_DIR:-/Users/jim/myKaraoke}"
ASSETS_FILE="$PROJECT_DIR/assets.json"
MIDI_COMPAT_PY="$PROJECT_DIR/tools/python/musescore_compat_midi.py"

export_musescore_musicxml() {
    echo "🎼 MuseScore Engraving Export Engine"
    echo "========================================================="

    local LIVE_MIDI
    LIVE_MIDI=$(jq -r '.inputs.source_midi // ""' "$ASSETS_FILE")
    if [[ -z "$LIVE_MIDI" ]]; then
        echo "❌ ERROR: assets.json is missing .inputs.source_midi"
        return 1
    fi

    local ABS_MIDI
    if [[ "$LIVE_MIDI" == /* ]]; then
        ABS_MIDI="$LIVE_MIDI"
    else
        ABS_MIDI="$PROJECT_DIR/$LIVE_MIDI"
    fi

    if [[ ! -f "$ABS_MIDI" ]]; then
        echo "❌ ERROR: Source MIDI not found: $ABS_MIDI"
        return 1
    fi

    local MIDI_DIR
    MIDI_DIR=$(dirname "$ABS_MIDI")
    local BASE_NAME
    BASE_NAME="$(basename "$ABS_MIDI")"
    BASE_NAME="${BASE_NAME%.*}"

    local SANITIZED_MIDI="$MIDI_DIR/${BASE_NAME}.sanitized.mid"

    echo "📝 Source MIDI:      $ABS_MIDI"
    echo "🧰 Sanitized out:    $SANITIZED_MIDI"
    echo ""

    # Keep original tempo map so engraving timing in MuseScore matches Logic.
    python3 "$MIDI_COMPAT_PY" "$ABS_MIDI" -o "$SANITIZED_MIDI" --keep-empty-lyrics --no-flatten-tempo
    if [[ $? -ne 0 ]]; then
        echo "❌ Sanitized MIDI conversion failed."
        return 1
    fi

    local REL_MIDI
    REL_MIDI=$(python3 - <<PY
import os
project = os.path.abspath("$PROJECT_DIR")
midi_path = os.path.abspath("$SANITIZED_MIDI")
print(os.path.relpath(midi_path, project))
PY
)

    local temp_json
    temp_json=$(mktemp)
    jq --arg p "$REL_MIDI" '.inputs.source_midi_sanitized = $p' "$ASSETS_FILE" > "$temp_json" && mv "$temp_json" "$ASSETS_FILE"

    echo "✅ Sanitized MIDI export complete."
    echo "📌 Registered .inputs.source_midi_sanitized = $REL_MIDI"
    echo "👉 Open this file in MuseScore for engraving edits."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    export_musescore_musicxml
fi
