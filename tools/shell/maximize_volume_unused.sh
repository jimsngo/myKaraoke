maximize_volume() {
    local CEILING=0.2
    local INPUT_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select file to maximize:")' 2>/dev/null)

    if [[ -z "$INPUT_FILE" ]]; then
        echo "⚠️  No file selected."
        return 1
    fi

    local OUTPUT_FILE="${INPUT_FILE%.*}_maximized.${INPUT_FILE##*.}"

    echo "🔍 Analyzing peak volume for: $(basename "$INPUT_FILE")..."
    local PEAK_DB=$(ffmpeg -i "$INPUT_FILE" -af "volumedetect" -vn -f null - 2>&1 | grep "max_volume:" | awk '{print $5}')

    if [ -z "$PEAK_DB" ]; then
        echo "❌ Could not detect volume."
        return 1
    fi

    local GAIN=$(echo "scale=2; -1 * ($PEAK_DB) - $CEILING" | bc)

    echo "📈 Applying gain: +${GAIN} dB"
    ffmpeg -y -i "$INPUT_FILE" -af "volume=${GAIN}dB" -c:v copy "$OUTPUT_FILE"

    echo "✅ Saved to: $OUTPUT_FILE"
}