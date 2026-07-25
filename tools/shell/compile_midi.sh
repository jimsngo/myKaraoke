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

    # 🛑 DYNAMIC MATH REMOVED: Bash no longer converts beats to seconds.
    # Python will handle the lead-in duration natively using the MIDI tempo map.

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
    
    # Inject raw beats directly into the execution environment for Python
    export LEAD_IN_BEATS="$LIVE_BEATS"
    export MIN_BREAK_GAP="$LIVE_GAP"

    echo "📥 Injecting musical context: $LIVE_BPM BPM | Lead-In: $LIVE_BEATS Beat(s) (Dynamic calculation in Python)"
    echo "📝 Input MIDI:  $ABS_MIDI"
    echo "📝 Output ASS:  $ABS_ASS"
    echo ""

    # Execute Python Subtitle Translation Stream with CLI output arg support
    python3 "$PYTHON_SCRIPT" "$ABS_MIDI" --out "$ABS_ASS" --alternate-rows --char-scroll
    
    if [[ $? -eq 0 ]]; then
        # === AUTO-TRUNCATE & EMOJI INJECTION ===
        local LIVE_AUDIO=$(jq -r '.inputs.instruments_only // ""' "$ASSETS_FILE")
        local ABS_AUDIO="$PROJECT_DIR/$LIVE_AUDIO"
        
        if [[ -f "$ABS_AUDIO" ]]; then
            echo "✂️  Trimming ghost duplicates and injecting Emoji Outro..."
            local AUDIO_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_AUDIO")
            
            # Use single quotes to protect the Python logic from Bash expansion
            python3 -c '
import sys

ass_file = sys.argv[1]
audio_dur = float(sys.argv[2])

def parse_time(t_str):
    h, m, s = t_str.split(":")
    return int(h)*3600 + int(m)*60 + float(s)

def format_time(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = seconds % 60
    return f"{h}:{m:02d}:{s:05.2f}"

with open(ass_file, "r", encoding="utf-8") as f:
    lines = f.readlines()

out_lines = []
last_dialogue_idx = -1
last_end_sec = 0

# 1. Prune ghost cards beyond audio duration
for line in lines:
    if line.startswith("Dialogue:"):
        parts = line.split(",", 9)
        start_sec = parse_time(parts[1])
        
        if start_sec >= audio_dur - 1.0:
            continue
            
        out_lines.append(line)
        last_dialogue_idx = len(out_lines) - 1
        last_end_sec = max(last_end_sec, parse_time(parts[2]))
    else:
        out_lines.append(line)

# 2. Enforce the Outro Emoji Rule
if last_dialogue_idx != -1:
    last_line = out_lines[last_dialogue_idx]
    emoji_tag = r"{\fnNoto Color Emoji\fs220}👍 ⭐⭐⭐⭐⭐ 👍" + "\n"
    
    if "[Instruments]" in last_line:
        # Overwrite a trapped instrument gap
        out_lines[last_dialogue_idx] = last_line.replace("[Instruments]\n", emoji_tag).replace("[Instruments]", emoji_tag)
    else:
        # Or append a clean Outro card if the song ends on vocals
        start_str = format_time(last_end_sec)
        end_str = format_time(audio_dur)
        outro_line = f"Dialogue: 0,{start_str},{end_str},Title,,0,0,0,,{emoji_tag}"
        out_lines.append(outro_line)

with open(ass_file, "w", encoding="utf-8") as f:
    f.writelines(out_lines)
' "$ABS_ASS" "$AUDIO_DUR"
        fi
        # =======================================

        # === AUTO-UPDATE ASSETS.JSON ===
        local REL_ASS="inputs/Subtitles/$(basename "$ABS_ASS")"
        python3 -c '
import sys, json
assets_file = sys.argv[1]
ass_path = sys.argv[2]
try:
    with open(assets_file, "r") as f:
        data = json.load(f)
    if "inputs" not in data:
        data["inputs"] = {}
    data["inputs"]["subtitles_ass"] = ass_path
    with open(assets_file, "w") as f:
        json.dump(data, f, indent=4)
    print("📝 Successfully linked .ass file in assets.json")
except Exception as e:
    print(f"⚠️ Warning: Could not update assets.json: {e}")
' "$ASSETS_FILE" "$REL_ASS"
        # =======================================
        
        echo "✅ Compilation success. Subtitles trimmed and finalized: $ABS_ASS"
    else
        echo "❌ Compilation failed."
        return 1
    fi
}

# Execute function natively
compile_midi_subtitles