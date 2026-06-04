#!/bin/bash
PROJECT_ROOT="/Users/jim/myKaraoke"
PRESETS="$PROJECT_ROOT/assets.json"

# --- 1. Load configuration and handle relative paths ---
REL_MAIN=$(jq -r '.inputs.main_audio // ""' "$PRESETS")
REL_SUB=$(jq -r '.inputs.subtitles // ""' "$PRESETS")
REL_BG=$(jq -r '.inputs.background // ""' "$PRESETS")

# Convert relative paths from JSON to absolute files for processing on Mac
ABS_MAIN="$PROJECT_ROOT/$REL_MAIN"
ABS_SUB="$PROJECT_ROOT/$REL_SUB"
ABS_BG="$PROJECT_ROOT/$REL_BG"

# --- 2. Determine song baseline name using original mixed track ---
if [[ -n "$REL_MAIN" ]]; then
    BASE_NAME=$(basename "$ABS_MAIN")
    # Strip any common suffix tags to get a clean song name root
    SONG_NAME=$(echo "${BASE_NAME%.*}" | sed -E 's/_(instruments|vocals|mixed)?(_optimized)?$//')
else
    SONG_NAME="lyrics_output"
fi

# Set up standardized capitalized output structure
mkdir -p "$PROJECT_ROOT/outputs/Lyrics"
ABS_OUTPUT_FILE="$PROJECT_ROOT/outputs/Lyrics/${SONG_NAME}_lyrics.mp4"
REL_OUTPUT_FILE="outputs/Lyrics/${SONG_NAME}_lyrics.mp4"

# --- 3. Validate Critical Assets ---
if [[ ! -f "$ABS_MAIN" ]]; then
    echo "❌ Error: Full mixed audio track file missing at: $ABS_MAIN"
    exit 1
fi
if [[ ! -f "$ABS_BG" ]]; then
    echo "❌ Error: Background video loop missing at: $ABS_BG"
    exit 1
fi

# Calculate length tracking boundaries using the full mixed track duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ABS_MAIN")

# --- 4. Render Video ---
VF_FILTER=""
# Inject subtitle video filter parameters safely if an .ass file exists
[[ -f "$ABS_SUB" ]] && VF_FILTER="subtitles='${ABS_SUB//\'/\\\'}'"

echo "🎬 Rendering Final Full-Mix Lyrics Video..."
echo "🎼 Base Song Title: $SONG_NAME"
echo "⏱️  Duration Match:   $DURATION seconds"

ffmpeg -y -stream_loop -1 -i "$ABS_BG" -i "$ABS_MAIN" \
       ${VF_FILTER:+-vf "$VF_FILTER"} \
       -map 0:v:0 -map 1:a:0 \
       -t "$DURATION" \
       -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k \
       "$ABS_OUTPUT_FILE"

if [[ $? -eq 0 ]]; then
    echo "✅ Lyrics Video Compiled Successfully!"
    
    # Save the output file path to assets.json (.outputs.lyrics_video sub-block)
    jq --arg p "$REL_OUTPUT_FILE" '.outputs.lyrics_video = $p' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
    
    echo "💾 Output location updated in assets.json: $REL_OUTPUT_FILE"
else
    echo "❌ ffmpeg error: Lyrics video generation failed."
    exit 1
fi