#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Helper — Compile MIDI with optional styles sidecar
# Script: tools/shell/compile_midi_with_styles.sh
# Purpose: Run midi_to_ass with an optional `--styles` sidecar file. Reads
#          `assets.json` for MIDI/ASS defaults if arguments omitted.
# ==============================================================================

PROJECT_DIR="${PROJECT_DIR:-/Users/jim/myKaraoke}"
PYTHON_SCRIPT="$PROJECT_DIR/tools/python/midi_to_ass.py"
ASSETS_FILE="$PROJECT_DIR/assets.json"

usage(){
    echo "Usage: $0 [styles_file]"
    echo "If no styles_file is given, the script will look for .inputs.styles in assets.json."
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

LIVE_MIDI=$(jq -r '.inputs.source_midi // ""' "$ASSETS_FILE")
LIVE_ASS=$(jq -r '.inputs.subtitles_ass // ""' "$ASSETS_FILE")
LIVE_STYLES=$(jq -r '.inputs.styles // ""' "$ASSETS_FILE")

if [[ -n "$1" ]]; then
    CLI_STYLES="$1"
else
    CLI_STYLES="$LIVE_STYLES"
fi

if [[ -z "$LIVE_MIDI" || -z "$LIVE_ASS" ]]; then
    echo "❌ ERROR: assets.json must define .inputs.source_midi and .inputs.subtitles_ass"
    exit 1
fi

ABS_MIDI="$LIVE_MIDI"
ABS_ASS="$LIVE_ASS"
if [[ "$LIVE_MIDI" != /* ]]; then ABS_MIDI="$PROJECT_DIR/$LIVE_MIDI"; fi
if [[ "$LIVE_ASS" != /* ]]; then ABS_ASS="$PROJECT_DIR/$LIVE_ASS"; fi

ABS_STYLES=""
if [[ -n "$CLI_STYLES" ]]; then
    if [[ "$CLI_STYLES" == /* ]]; then
        ABS_STYLES="$CLI_STYLES"
    else
        ABS_STYLES="$PROJECT_DIR/$CLI_STYLES"
    fi
fi

if [[ ! -f "$ABS_MIDI" ]]; then
    echo "❌ ERROR: MIDI file not found: $ABS_MIDI"
    exit 1
fi

echo "📥 MIDI:  $ABS_MIDI"
echo "📤 ASS:   $ABS_ASS"
if [[ -n "$ABS_STYLES" ]]; then echo "🎨 Styles: $ABS_STYLES"; fi
echo ""

CMD=("python3" "$PYTHON_SCRIPT" "$ABS_MIDI" "--out" "$ABS_ASS")
if [[ -n "$ABS_STYLES" ]]; then
    CMD+=("--styles" "$ABS_STYLES")
fi

"${CMD[@]}"
RC=$?
if [[ $RC -eq 0 ]]; then
    echo "✅ Compilation complete: $ABS_ASS"
else
    echo "❌ Compilation failed (exit $RC)"
fi

exit $RC
