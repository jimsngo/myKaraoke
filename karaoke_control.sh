#!/bin/bash
# ==============================================================================
# PROJECT: myKaraoke Controller (v2.0 - Strict Filtering & Silent Video)
# ==============================================================================

PROJECT_DIR="/Users/jim/myKaraoke"
WORKER_SCRIPT="$PROJECT_DIR/tools/shell/create_video.sh"

clear
echo "----------------------------------------------------------------"
echo "        ✝️  myKaraoke Voyage Control (v2.0) ✝️      "
echo "----------------------------------------------------------------"

# 1. FILE PICKERS (Strictly Filtered)
# Audio Pickers: Restricts to common audio formats
AUDIO_1=$(osascript -e 'POSIX path of (choose file with prompt "Select Primary Audio (Vocal):" of type {"mp3", "wav", "m4a", "flac", "aif", "aiff"})')
[[ -z "$AUDIO_1" ]] && exit 1

AUDIO_2=$(osascript -e 'POSIX path of (choose file with prompt "Select Secondary Audio (Backing):" of type {"mp3", "wav", "m4a", "flac", "aif", "aiff"})')
[[ -z "$AUDIO_2" ]] && exit 1

# Background Picker: Allows images and videos
BG_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select Background (Image or Video):" of type {"jpg", "jpeg", "png", "gif", "heic", "mp4", "mov", "mkv"})')
[[ -z "$BG_FILE" ]] && exit 1

# Subtitle Picker: STRICTLY .ass only
ASS_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select Subtitles (.ass):" of type {"ass"})')
[[ -z "$ASS_FILE" ]] && exit 1

# 2. PREFERENCES (Smart Logic)
# Default values applied immediately for your Sunday Mass projects
SEG_TIME=10
FPS=21
CRF=23

# Only ask for Voyage/FPS/CRF settings if an IMAGE is selected
if [[ "$BG_FILE" =~ \.(jpg|jpeg|png|gif|heic|JPG|JPEG|PNG|HEIC)$ ]]; then
    echo -e "\n🖼️  Image Detected: Configuring Voyage Engine..."
    
    echo -n "⏱️  Quadrant Cycle Duration (seconds) [Default 10]: "
    read SEG_INPUT
    SEG_TIME=${SEG_INPUT:-10}

    echo -n "🎞️  Video Playback FPS [Default 21]: "
    read FPS_INPUT
    FPS=${FPS_INPUT:-21}

    echo -n "📉 Quality/Size (CRF 18-28) [Default 23]: "
    read CRF_INPUT
    CRF=${CRF_INPUT:-23}
else
    # Silent bypass for Video Loops as requested
    echo -e "\n🎬 Video Loop Detected: Bypassing Preference Settings..."
    echo "🔹 Using Defaults: FPS=$FPS, CRF=$CRF"
fi

# 3. RUN WORKER
bash "$WORKER_SCRIPT" "$AUDIO_1" "$BG_FILE" "$ASS_FILE" "$SEG_TIME" "$FPS" "$CRF" "$AUDIO_2"

# 4. NOTIFY
afplay /System/Library/Sounds/Glass.aiff
echo "✅ Done! Lyrics and Karaoke videos generated."