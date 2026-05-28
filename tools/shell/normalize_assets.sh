#!/bin/bash
BG="$1"
OV="$2"
OUT="$3"

echo "🔨 Testing simple overlay..."

# We don't scale. We don't force color. We just overlay.
ffmpeg -y -stream_loop -1 -i "$BG" -stream_loop -1 -i "$OV" \
    -filter_complex "overlay=0:0" \
    -t 10 -c:v libx264 -preset ultrafast -an "$OUT"