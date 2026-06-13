#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 5 Module (One-Pass MIDI Compiler)
# 
# Summary:
#   Non-interactive compiler that transforms SynthV MIDI exports into .ass 
#   subtitle tracks using the assets.json registry.
#
# Inputs:
#   - MIDI_FILE: [inputs/midi/...] Path retrieved from assets.json['inputs']['source_midi']
#   - TXT_FILE:  [inputs/text/...] Static reference derived from audio base name
#
# Outputs:
#   - ASS_FILE:  [inputs/subtitles/...] Path retrieved from assets.json['inputs']['subtitles_ass']
# ==============================================================================

# --- PRE-DEFINED PATHS ---
PROJECT_DIR="/Users/jim/myKaraoke"
PYTHON_SCRIPT="$PROJECT_DIR/tools/python/midi_to_ass.py"

# Resolve paths directly from the exported environment variables
ABS_MIDI="$PROJECT_DIR/$MIDI_FILE"
ABS_ASS="$PROJECT_DIR/$SUBTITLES_ASS"

compile_midi_subtitles() {
    echo "🎼 Synth V MIDI Subtitle Compiler Engine"
    echo "========================================================="

    # Validation: Ensure inputs exist before triggering Python
    if [[ ! -f "$ABS_MIDI" ]]; then
        echo "❌ ERROR: MIDI file not found at: $ABS_MIDI"
        return 1
    fi

    # Execute Python Compiler
    python3 "$PYTHON_SCRIPT" "$ABS_MIDI" "$ABS_ASS"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Compilation success. Subtitles saved to: $ABS_ASS"
    else
        echo "❌ Compilation failed."
        return 1
    fi
}

# Run the function
compile_midi_subtitles