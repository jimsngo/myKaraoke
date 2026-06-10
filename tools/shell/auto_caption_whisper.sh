#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 4 Module
# Script: tools/shell/auto_caption_whisper.sh
# Purpose: Transcribes isolated vocal audio into timestamped Whisper .srt captions.
#
# Schema Dependency Guards:
#   👉 Required .inputs Keys: [ vocals_only ]
#
# Safeguard Mechanism:
#   Intercepts execution immediately during the local variables declaration phase. 
#   If a key was renamed in assets.json but left un-updated here, it halts execution
#   instantly to isolate the break, preventing silent downstream tracking failures.
# ==============================================================================

auto_caption_whisper() {
    # Define clean, local environment contexts independent of the master dashboard state
    local PROJECT_DIR="/Users/jim/myKaraoke"
    local INPUT_DIR="$PROJECT_DIR/inputs"
    local PRESETS="$PROJECT_DIR/assets.json"
    local JSON_GUARD="$PROJECT_DIR/tools/shell/validate_json.sh"

    # 🛠️ SAFEGUARD CHECK: Declare the exact keys this option script relies on to execute
    local REQUIRED_ASSET_KEYS=(
        "vocals_only"
    )

    if [[ -f "$JSON_GUARD" ]]; then
        source "$JSON_GUARD"
        validate_required_keys "$(basename "$0")" "${REQUIRED_ASSET_KEYS[@]}"
    else
        echo "⚠️  Warning: Central validate_json.sh guard missing. Proceeding without safety check..."
    fi

    # --- Active Whisper Transcription Pipeline Runs Safely Below ---
    # Extract the required tracking path fresh from the JSON database
    local VOCALS_ONLY=$(jq -r '.inputs.vocals_only // ""' "$PRESETS")

    if [[ -z "$VOCALS_ONLY" || ! -f "$PROJECT_DIR/$VOCALS_ONLY" ]]; then
        echo "❌ Error: Vocals track file not found on disk."
        echo "   Please run Option 2 (Demucs Split / Import) first to isolate the vocals."
        return 1
    fi

    local ABS_VOCALS="$PROJECT_DIR/$VOCALS_ONLY"
    local BASE_NAME=$(basename "$ABS_VOCALS")
    local TRACK_NAME="${BASE_NAME%_vocals.*}"

    # Force a clean lowercase directory tree to match your global blueprint
    local SUB_DIR="$INPUT_DIR/subtitles"
    mkdir -p "$SUB_DIR"
    
    local ABS_OUTPUT_SRT="$SUB_DIR/${TRACK_NAME}.srt"
    local REL_OUTPUT_SRT="inputs/subtitles/${TRACK_NAME}.srt"

    echo ""
    echo "🌐 Select Transcription Language:"
    echo "1) Vietnamese (Default)"
    echo "2) English"
    read -p "Choose option [1-2, Enter for Default]: " lang_choice

    local LANG_CODE="vi"
    if [[ "$lang_choice" == "2" ]]; then
        LANG_CODE="en"
    fi

    echo "⏳ Initializing Whisper execution workspace on host CPU..."
    echo "🤖 Loading model dimensions (This may take a few seconds)..."
    
    # Run your robust, inline Python Whisper audio parsing engine
    python3 - <<EOF
import sys
import os

try:
    print("[DEBUG] 1/6: Validating audio track properties...")
    if not os.path.exists("$ABS_VOCALS"):
        print("❌ Error: Audio stream reference is invalid", file=sys.stderr)
        sys.exit(1)

    print("[DEBUG] 2/6: Importing runtime environment metrics...")
    import torch
    
    print("[DEBUG] 3/6: Loading Whisper tracking core libraries...")
    import whisper
    from whisper.utils import get_writer

    print("[DEBUG] 4/6: Instantiating base engine on host CPU...")
    model = whisper.load_model("base", device="cpu")
    
    print("[DEBUG] 5/6: Processing audio blocks (Word Timestamps Enabled)...")
    result = model.transcribe(
        "$ABS_VOCALS",
        language="$LANG_CODE",
        word_timestamps=True,
        condition_on_previous_text=False
    )
    
    print("[DEBUG] 6/6: Complete! Exporting compiled timeframes...")
    writer = get_writer("srt", "$SUB_DIR")
    writer(result, "$ABS_VOCALS", {})
    sys.exit(0)
    
except Exception as e:
    print(f"\n❌ Python Runtime Error: {str(e)}", file=sys.stderr)
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        # Re-align naming patterns if Whisper's built-in writer appended an unexpected extension format
        local GENERATED_SRT="$SUB_DIR/${BASE_NAME%.*}.srt"
        if [ -f "$GENERATED_SRT" ] && [ "$GENERATED_SRT" != "$ABS_OUTPUT_SRT" ]; then
            mv "$GENERATED_SRT" "$ABS_OUTPUT_SRT"
        fi

        if [ -f "$ABS_OUTPUT_SRT" ]; then
            echo "✅ Auto-captioning successful!"
            
            # Write out exclusively to your subtitles_srt_whisper tracking target inside assets.json
            local temp_json=$(mktemp)
            jq --arg p "$REL_OUTPUT_SRT" '.inputs.subtitles_srt_whisper = $p' "$PRESETS" > "$temp_json" && mv "$temp_json" "$PRESETS"
            
            echo "📝 Registered Whisper SRT asset path: $REL_OUTPUT_SRT"
        else
            echo "❌ Error: Subtitle output file was not detected at $ABS_OUTPUT_SRT"
            return 1
        fi
    else
        echo "❌ Error parsing transcription data via Python core engine."
        return 1
    fi
}

# Execute loop block when triggered directly from command terminal environment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    auto_caption_whisper
fi