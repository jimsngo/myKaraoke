#!/bin/bash
# ==============================================================================
# PROJECT: myKaraoke Controller (v2.2 - Main Menu & GitHub Integration)
# ==============================================================================

PROJECT_DIR="/Users/jim/myKaraoke"
WORKER_SCRIPT="$PROJECT_DIR/tools/shell/create_video.sh"

clear
echo "----------------------------------------------------------------"
echo "        ✝️  myKaraoke Voyage Control (v2.2) ✝️      "
echo "----------------------------------------------------------------"
echo " 1) 🎬 Create New Karaoke Video"
echo " 2) ☁️  Push Scripts to GitHub (Manual Sync)"
echo " 3) 🚪 Exit"
echo "----------------------------------------------------------------"
echo -n "Select an option [1-3]: "
read MAIN_CHOICE

case $MAIN_CHOICE in
    2)
        echo -e "\n📤 Uploading to jimsngo/myKaraoke..."
        cd "$PROJECT_DIR"
        git add .
        git commit -m "Manual script sync: $(date +'%Y-%m-%d %H:%M')"
        git push origin main
        echo "✅ GitHub sync complete!"
        exit 0
        ;;
    3)
        echo "👋 Goodbye!"
        exit 0
        ;;
    1)
        # Proceed to the creation steps below
        echo -e "\n🎬 Starting Video Creation..."
        ;;
    *)
        echo "❌ Invalid option. Exiting."
        exit 1
        ;;
esac

# --- 1. FILE PICKERS ---
AUDIO_1=$(osascript -e 'POSIX path of (choose file with prompt "Select Primary Audio (Vocal):" of type {"mp3", "wav", "m4a", "flac", "aif", "aiff"})')
[[ -z "$AUDIO_1" ]] && exit 1

AUDIO_2=$(osascript -e 'POSIX path of (choose file with prompt "Select Secondary Audio (Backing):" of type {"mp3", "wav", "m4a", "flac", "aif", "aiff"})')
[[ -z "$AUDIO_2" ]] && exit 1

BG_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select Background (Image or Video):" of type {"jpg", "jpeg", "png", "gif", "heic", "mp4", "mov", "mkv"})')
[[ -z "$BG_FILE" ]] && exit 1

ASS_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select Subtitles (.ass):" of type {"ass"})')
[[ -z "$ASS_FILE" ]] && exit 1

# --- 2. PREFERENCES ---
SEG_TIME=10
FPS=21
CRF=23

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
fi

# --- 3. EXECUTION ---
echo -e "\n🚀 Launching Engine..."
bash "$WORKER_SCRIPT" "$AUDIO_1" "$BG_FILE" "$ASS_FILE" "$SEG_TIME" "$FPS" "$CRF" "$AUDIO_2"

# --- 4. POST-RENDER GITHUB SYNC ---
echo -e "\n----------------------------------------------------------------"
echo -n "☁️  Render finished. Push script updates to GitHub? (y/n): "
read PUSH_CONFIRM

if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "📤 Uploading to jimsngo/myKaraoke..."
    cd "$PROJECT_DIR"
    git add .
    git commit -m "Update scripts after render: $(date +'%Y-%m-%d %H:%M')"
    git push origin main
    echo "✅ GitHub sync complete!"
else
    echo "👋 Skipping GitHub upload."
fi

echo -e "\n✨ Process Finished."