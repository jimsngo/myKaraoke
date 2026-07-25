#!/bin/bash

echo "📦 Extracting file paths from assets.json..."

# Use Python to safely parse the JSON paths based on the new architecture
INSTRUMENTS=$(python3 -c "import json; print(json.load(open('assets.json'))['inputs']['instruments_only'])")
SUBTITLES=$(python3 -c "import json; d=json.load(open('assets.json'))['inputs']; print(d.get('subtitles_production_ass', d.get('subtitles_ass')))")
BACKGROUND=$(python3 -c "import json; print(json.load(open('assets.json'))['outputs']['background_video'])")

echo "🎵 Instruments: $INSTRUMENTS"
echo "💬 Subtitles: $SUBTITLES"
echo "🖼️  Background: $BACKGROUND"
echo ""

echo "🗜️  Zipping required files for Option 9..."

# Create the zip archive, preserving the directory structure
zip colab_render.zip assets.json "$INSTRUMENTS" "$SUBTITLES" "$BACKGROUND"

echo ""
echo "✅ Done! 'colab_render.zip' is ready to be uploaded to Colab."