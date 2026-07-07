#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 5 Module (Beat-Adaptive Mode)
# Script: tools/shell/compile_midi.sh
# Purpose: Environment wrapper for Logic MIDI translation. Cleaned up to strictly enforce
#          your single-tempo truth by completely stripping out old midi_bpm values.
# ==============================================================================

# --- PRE-DEFINED PATHS ---
PROJECT_DIR="${PROJECT_DIR:-/Users/jim/myKaraoke}"
PYTHON_SCRIPT="$PROJECT_DIR/tools/python/midi_to_ass.py"
ASSETS_FILE="$PROJECT_DIR/assets.json"

compile_midi_subtitles() {
    echo "🎼 Logic Pro MIDI Subtitle Compiler Engine (Beat-Adaptive Mode)"
    echo "========================================================="

    # LIVE DATABASE LOOKUP: Fetch values freshly from disk
    local LIVE_MIDI=$(jq -r '.inputs.source_midi // ""' "$ASSETS_FILE")
    local LIVE_ASS=$(jq -r '.inputs.subtitles_ass // ""' "$ASSETS_FILE")
    
    # 💡 PURIFIED LOOKUP: Enforce your uploaded single-tempo truth strictly
    local LIVE_BPM=$(jq -r '.inputs.bpm // "120"' "$ASSETS_FILE")
    local LIVE_KEY=$(jq -r '.inputs.midi_key // "C-Major"' "$ASSETS_FILE")
    local LIVE_SPB=$(jq -r '.inputs.seconds_per_beat // "0.5"' "$ASSETS_FILE")

    # Extract configuration settings thresholds (Thinking in Beats!)
    local LIVE_BEATS=$(jq -r '.settings.lead_in_beats // "1.0"' "$ASSETS_FILE")
    local LIVE_GAP=$(jq -r '.settings.min_break_gap // "1.0"' "$ASSETS_FILE")

    # DYNAMIC TRANSLATION MATH: Convert your musical beats into clock seconds on the fly
    local LIVE_LEAD=$(awk "BEGIN {print $LIVE_BEATS * $LIVE_SPB}")

    # Force absolute paths for the file systems
    local ABS_MIDI
    if [[ "$LIVE_MIDI" == /* ]]; then ABS_MIDI="$LIVE_MIDI"; else ABS_MIDI="$PROJECT_DIR/$LIVE_MIDI"; fi

    local ABS_ASS
    # Derive a sane default ASS path inside inputs/Subtitles using the MIDI basename
    local MIDI_BASENAME
    MIDI_BASENAME=$(basename "$ABS_MIDI")
    MIDI_BASENAME="${MIDI_BASENAME%.*}"
    local DEFAULT_ASS="$PROJECT_DIR/inputs/Subtitles/${MIDI_BASENAME}.ass"

    # Always derive ASS path from the MIDI basename to enforce consistent naming
    ABS_ASS="$DEFAULT_ASS"

    # Ensure directory exists
    mkdir -p "$(dirname "$ABS_ASS")"

    # Validation: Ensure inputs exist before running Python compiler
    if [[ -z "$LIVE_MIDI" || ! -f "$ABS_MIDI" ]]; then
        echo "❌ ERROR: Target MIDI file not found at: $ABS_MIDI"
        return 1
    fi

    # Export universal workspace parameters to the environment
    export MIDI_FILE="$ABS_MIDI"
    export SUBTITLES_ASS="$ABS_ASS"
    
    # 💡 PURIFIED ENVIRONMENTAL EXPORTS: midi_bpm is permanently removed
    export BPM="$LIVE_BPM"
    export MIDI_KEY="$LIVE_KEY"
    export SECONDS_PER_BEAT="$LIVE_SPB"
    
    # Inject computed clock math directly into the execution environment for python
    export LEAD_IN_SECONDS="$LIVE_LEAD"
    export MIN_BREAK_GAP="$LIVE_GAP"

    echo "📥 Injecting musical context: $LIVE_BPM BPM | Lead-In: $LIVE_BEATS Beat(s) ($LIVE_LEAD seconds)"
    echo "📝 Input MIDI:  $ABS_MIDI"
    echo "📝 Output ASS:  $ABS_ASS"
    echo ""

    # Execute Python Subtitle Translation Stream with CLI output arg support
    python3 "$PYTHON_SCRIPT" "$ABS_MIDI" --out "$ABS_ASS"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Compilation success. Subtitles saved to: $ABS_ASS"
    else
        echo "❌ Compilation failed."
        return 1
    fi
}

# Execute function natively
compile_midi_subtitles