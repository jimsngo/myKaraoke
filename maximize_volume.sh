#!/bin/bash

# Configuration
CEILING=0.2 

# Function to pick a file using macOS UI
pick_file() {
    osascript -e 'POSIX path of (choose file with prompt "Select the audio or video file to maximize:" default location (path to desktop folder))' 2>/dev/null
}

# 1. Try to get file from Picker
INPUT_FILE=$(pick_file)

# 2. Fallback to Drag-and-Drop if picker returns nothing
if [ -z "$INPUT_FILE" ]; then
    echo "⚠️  No file selected or Picker cancelled."
    echo "Please drag and drop your file into the terminal window, then press Enter:"
    read -r INPUT_FILE
    INPUT_FILE=$(echo "$INPUT_FILE" | tr -d "'")
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "❌ Error: File '$INPUT_FILE' not found."
    exit 1
fi

OUTPUT_FILE="${INPUT_FILE%.*}_maximized.${INPUT_FILE##*.}"

echo "🔍 Analyzing peak volume for: $(basename "$INPUT_FILE")..."

# 3. Detect Peak
PEAK_DB=$(ffmpeg -i "$INPUT_FILE" -af "volumedetect" -vn -f null - 2>&1 | grep "max_volume:" | awk '{print $5}')

if [ -z "$PEAK_DB" ]; then
    echo "❌ Could not detect volume."
    exit 1
fi

# 4. Calculate stats
HEADROOM=$(echo "scale=2; 0 - (-1 * ($PEAK_DB))" | bc)
GAIN=$(echo "scale=2; -1 * ($PEAK_DB) - $CEILING" | bc)

echo "----------------------------------------------------"
echo "📊 Current peak: ${PEAK_DB} dB"
echo "📏 Headroom detected: +${HEADROOM} dB"
echo "📈 Applying gain: +${GAIN} dB (to reach -${CEILING} dBTP)"
echo "----------------------------------------------------"

# 5. Apply gain
ffmpeg -i "$INPUT_FILE" -af "volume=${GAIN}dB" -c:v copy "$OUTPUT_FILE"

echo "✅ Success! Maximized file saved to: $OUTPUT_FILE"
