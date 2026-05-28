pick_file() {
    osascript -e "POSIX path of (choose file with prompt \"$1\" default location (path to desktop folder))" 2>/dev/null
}

maximize_volume() {
    local CEILING=0.2
    local INPUT_FILE=$(pick_file "Select file to maximize")
    if [[ -z "$INPUT_FILE" ]]; then return; fi
    local OUTPUT_FILE="${INPUT_FILE%.*}_maximized.${INPUT_FILE##*.}"
    local PEAK_DB=$(ffmpeg -i "$INPUT_FILE" -af "volumedetect" -vn -f null - 2>&1 | grep "max_volume:" | awk '{print $5}')
    if [ -z "$PEAK_DB" ]; then return; fi
    local GAIN=$(echo "scale=2; -1 * ($PEAK_DB) - $CEILING" | bc)
    ffmpeg -y -i "$INPUT_FILE" -af "volume=${GAIN}dB" -c:v copy "$OUTPUT_FILE"
}

scan_loudness() {
    local FILE=$(pick_file "Select file to scan")
    if [[ -z "$FILE" ]]; then return; fi
    ffmpeg -i "$FILE" -af loudnorm=I=-16:print_format=summary -f null -
    read -p "Press Enter to continue..."
}

strip_audio() {
    local INPUT_FILE=$(pick_file "Select video to strip")
    if [[ -z "$INPUT_FILE" ]]; then return; fi
    local OUTPUT_FILE="${INPUT_FILE%.*}_no_audio.${INPUT_FILE##*.}"
    ffmpeg -y -i "$INPUT_FILE" -an -c:v copy "$OUTPUT_FILE"
}