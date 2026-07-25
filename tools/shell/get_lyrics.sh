#!/bin/bash

# If no argument is passed, prompt the user for the URL
if [ -z "$1" ]; then
    echo -n "🔗 Enter YouTube URL: "
    read -r URL
else
    URL="$1"
fi

# Exit if the input is empty
if [ -z "$URL" ]; then
    echo "❌ Error: No URL provided. Exiting."
    exit 1
fi

echo "🚀 Fetching Vietnamese auto-captions..."

# Execute the isolated yt-dlp command
yt-dlp --skip-download --write-auto-subs --sub-langs vi --convert-subs srt --no-playlist "$URL"

# Check if the command succeeded
if [ $? -eq 0 ]; then
    echo "✅ Success! Your .srt file has been generated in the current directory."
    echo "📂 File list:"
    ls -l *.srt 2>/dev/null
else
    echo "❌ Download failed."
    echo "💡 Tip: If you get a 429 error, try updating your tool: python3 -m pip install -U yt-dlp"
fi