strip_audio() {
    local INPUT_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select video to strip audio from:")' 2>/dev/null)

    if [[ -z "$INPUT_FILE" ]]; then
        return 1
    fi

    local OUTPUT_FILE="${INPUT_FILE%.*}_no_audio.${INPUT_FILE##*.}"
    echo "✂️  Stripping audio from: $(basename "$INPUT_FILE")..."
    
    ffmpeg -y -i "$INPUT_FILE" -an -c:v copy "$OUTPUT_FILE"
    echo "✅ Success! Saved to: $OUTPUT_FILE"
}