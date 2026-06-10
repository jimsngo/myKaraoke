#!/bin/bash
# Library: tools/shell/purge_outputs.sh

purge_outputs() {
    # Define clean, local environment contexts independent of the master dashboard state
    local PROJECT_ROOT="/Users/jim/myKaraoke"
    local TARGET_KARAOKE="$PROJECT_ROOT/outputs/karaoke"
    local TARGET_LYRICS="$PROJECT_ROOT/outputs/lyrics"

    echo "🗑️  Initializing production output storage purge..."
    echo "⚠️  This will permanently delete all rendered video files in outputs/."
    read -p "Are you absolutely sure you want to clear these directories? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "⏳ Clearing target rendering targets..."

        # 1. Clear out Karaoke output folder safely if it exists
        if [[ -d "$TARGET_KARAOKE" ]]; then
            rm -rf "$TARGET_KARAOKE"/*
            echo "🧹 Emptied: outputs/karaoke/"
        else
            mkdir -p "$TARGET_KARAOKE"
        fi

        # 2. Clear out Lyrics output folder safely if it exists
        if [[ -d "$TARGET_LYRICS" ]]; then
            rm -rf "$TARGET_LYRICS"/*
            echo "🧹 Emptied: outputs/lyrics/"
        else
            mkdir -p "$TARGET_LYRICS"
        fi

        echo "✅ Canvas workspace directories cleanly cleared!"
    else
        echo "Authorization bypassed. ⏭️  Purge sequence aborted."
    fi
}