#!/bin/bash
# Library: tools/shell/auto_caption_whisper.sh

PROJECT_DIR="/Users/jim/myKaraoke"
INPUT_DIR="$PROJECT_DIR/inputs"
PRESETS="$PROJECT_DIR/assets.json"

load_assets() {
    if [[ -f "$PRESETS" ]]; then
        export VOCALS_ONLY=$(jq -r '.inputs.vocals_only // ""' "$PRESETS")
    fi
}

auto_caption_vocals() {
    load_assets

    if [[ -z "$VOCALS_ONLY" || ! -f "$PROJECT_DIR/$VOCALS_ONLY" ]]; then
        echo "❌ Error: Vocals track not found in assets.json."
        echo "   Please run Option 1 (Demucs Split) first to isolate the vocals."
        return 1
    fi

    local ABS_VOCALS="$PROJECT_DIR/$VOCALS_ONLY"
    local BASE_NAME=$(basename "$ABS_VOCALS")
    local TRACK_NAME="${BASE_NAME%_vocals.*}"

    local SUB_DIR="$INPUT_DIR/Subtitles"
    mkdir -p "$SUB_DIR"
    
    local ABS_OUTPUT_SRT="$SUB_DIR/${TRACK_NAME}.srt"
    local REL_OUTPUT_SRT="inputs/Subtitles/${TRACK_NAME}.srt"

    echo ""
    echo "🌐 Select Transcription Language:"
    echo "1) Vietnamese (Default)"
    echo "2) English"
    read -p "Choose option [1-2, Enter for Default]: " lang_choice

    local LANG_CODE="vi"
    if [[ "$lang_choice" == "2" ]]; then
        LANG_CODE="en"
        echo "🇺🇸 Selected Language: English"
    else
        echo "🇻🇳 Selected Language: Vietnamese"
    fi
    echo ""

    echo "🤖 Initializing Hardened Whisper Engine..."
    echo "🎤 Target Track: $BASE_NAME"
    echo "⏳ Transcribing..."

    # 1. Hard OS environment locks to prevent multi-threading overhead/crashes
    export KMP_DUPLICATE_LIB_OK=TRUE
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1
    export VECLIB_MAXIMUM_THREADS=1
    export NUMEXPR_NUM_THREADS=1
    export NUMBA_NUM_THREADS=1
    export NUMBA_THREADING_LAYER="workqueue"

    # 2. Inline Python isolation script with active phase debugging
    python3 <<EOF
import os
import sys
import warnings

# Suppress framework layout deprecation warnings
warnings.filterwarnings("ignore")

print("[DEBUG] 1/6: Setting process runtime environment flags...")
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["NUMBA_NUM_THREADS"] = "1"
os.environ["NUMBA_THREADING_LAYER"] = "workqueue"

try:
    print("[DEBUG] 2/6: Importing torch backend structures...")
    import torch
    torch.set_num_threads(1)
    torch.set_num_interop_threads(1)
    
    print("[DEBUG] 3/6: Loading Whisper module and components...")
    import whisper
    from whisper.utils import get_writer

    print("[DEBUG] 4/6: Instantiating base model engine on host CPU...")
    model = whisper.load_model("base", device="cpu")
    
    print("[DEBUG] 5/6: Executing transcription process (Word Timestamps Enabled)...")
    result = model.transcribe(
        "$ABS_VOCALS",
        language="$LANG_CODE",
        word_timestamps=True,
        condition_on_previous_text=False
    )
    
    print("[DEBUG] 6/6: Generation complete. Exporting SRT file assets...")
    writer = get_writer("srt", "$SUB_DIR")
    writer(result, "$ABS_VOCALS", {})
    sys.exit(0)
    
except Exception as e:
    print(f"\n❌ Python Execution Error: {str(e)}", file=sys.stderr)
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        local GENERATED_SRT="$SUB_DIR/${BASE_NAME%.*}.srt"
        if [ -f "$GENERATED_SRT" ] && [ "$GENERATED_SRT" != "$ABS_OUTPUT_SRT" ]; then
            mv "$GENERATED_SRT" "$ABS_OUTPUT_SRT"
        fi

        if [ -f "$ABS_OUTPUT_SRT" ]; then
            echo "✅ Auto-captioning successful!"
            jq --arg p "$REL_OUTPUT_SRT" '.inputs.subtitles = $p' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
            echo "💾 Registered to configuration: $REL_OUTPUT_SRT"
            return 0
        fi
    fi

    echo "❌ Error: Whisper caption execution failed or aborted."
    return 1
}

# Explicitly invoke the module execution branch
auto_caption_vocals