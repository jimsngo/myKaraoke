scan_loudness() {
    local FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select Audio/Video file:")' 2>/dev/null)

    if [[ -z "$FILE" ]]; then
        echo "❌ No file selected."
        return 1
    fi

    echo "🔍 Scanning: $(basename "$FILE")..."
    ffmpeg -i "$FILE" -af loudnorm=I=-16:print_format=summary -f null -
    read -p "Press Enter to return to menu..."
}