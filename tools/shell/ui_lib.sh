#!/bin/bash
# Library: tools/shell/ui_lib.sh

display_menu() {
    clear
    
    # Establish local path references for real-time asset checks
    local PRESETS_FILE="/Users/jim/myKaraoke/assets.json"
    local CURRENT_TRACK="No Active Song Session"
    
    if [[ -f "$PRESETS_FILE" ]]; then
        local TITLE=$(jq -r '.inputs.song_title // ""' "$PRESETS_FILE")
        local AUTHOR=$(jq -r '.inputs.song_author // ""' "$PRESETS_FILE")
        
        if [[ -n "$TITLE" ]]; then
            if [[ -n "$AUTHOR" ]]; then
                CURRENT_TRACK="$TITLE ($AUTHOR)"
            else
                CURRENT_TRACK="$TITLE"
            fi
        fi
    fi

    echo -e "\033[1;36m=========================================================\033[0m"
    echo -e "\033[1;36m             🎤  myKaraoke Automation Console  🎤        \033[0m"
    echo -e "\033[1;36m=========================================================\033[0m"
    echo -e "🎵 Active Project: \033[1;32m$CURRENT_TRACK\033[0m"
    echo -e "\033[1;36m=========================================================\033[0m"
    echo ""
    
    echo -e "\033[1;33m🌐 Preview Control Room:\033[0m"
    echo "  1) Open Web Browser Preview Room (Sync Check Room)"
    echo ""

    echo -e "\033[1;33m🎼 Audio Stem Engineering:\033[0m"
    echo "  2) AI Stem Separation Engine     (Demucs Split Tracks)"
    echo "  3) Optimize Track Headroom Peaks (Normalize Gain DB)"
    echo ""

    echo -e "\033[1;33m📝 Subtitle Tracking Alignment:\033[0m"
    echo "  4) Deploy Whisper AI Transcription (Auto-Caption Vocals)"
    echo "  5) Compile Subtitles From Synth V MIDI Track (Dual Export)"
    echo "  6) Import External Production .ASS Subtitle File Layouts"
    echo ""

    echo -e "\033[1;33m🎬 Video Rendering Suite:\033[0m"
    echo "  7) Strip Audio Layer Out From Background Reference Videos"
    echo "  8) Import & Optimize Background Scenery Videos"
    echo "  9) Generate High-Res Final Karaoke Video"
    echo " 10) Generate Alternative Full-Mix Lyrics Presentation Video"
    echo ""

    echo -e "\033[1;33m⚙️  Workspace Management:\033[0m"
    echo " 11) Purge Local Render Output Storage Files"
    echo " 12) Synchronize Project Canvas State Safely to GitHub"
    echo " 13) Validate Project Assets and Naming Consistency"
    echo ""
    echo -e "\033[1;36m=========================================================\033[0m"
}