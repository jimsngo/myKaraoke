#!/bin/bash
# ==============================================================================
# PROJECT: myKaraoke Video Engine (v2.0 - Stable Full)
# ==============================================================================

AUDIO_1="$1"
BG_PATH="$2"
ASS_PATH="$3"
SEG_TIME="$4"
FPS="$5"
CRF="$6"
AUDIO_2="$7"

PROJECT_DIR="/Users/jim/myKaraoke"
LOCAL_TMP="$PROJECT_DIR/.tmp"
mkdir -p "$LOCAL_TMP"

# STEP 1: Copy Subtitles to a local temp file
TEMP_ASS="$LOCAL_TMP/render.ass"
cp "$ASS_PATH" "$TEMP_ASS"

# STEP 2: Logic & Math
SDUR=$(echo "$SEG_TIME * $FPS" | bc | cut -d'.' -f1)
TOTAL_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_1")
TOTAL_FRAMES=$(echo "$TOTAL_DUR * $FPS" | bc | cut -d'.' -f1)
END_START=$((TOTAL_FRAMES - SDUR))

MP3_DIR="$(cd "$(dirname "$AUDIO_1")" && pwd)"
MP3_BASE="$(basename "$AUDIO_1" | sed 's/\.[^.]*$//')"
LYRICS_OUT="$MP3_DIR/${MP3_BASE}_lyrics.mp4"
KARAOKE_OUT="$MP3_DIR/${MP3_BASE}_karaoke.mp4"

# Escape colons, spaces, and single quotes for the subtitle filter (Crucial for macOS)
ESC_ASS=$(echo "$TEMP_ASS" | sed "s/[:' ]/\\\\&/g")
SUB_FILTER="subtitles='${ESC_ASS}'"

# STEP 3: Split Logic (Image vs Video)
if [[ "$BG_PATH" =~ \.(jpg|jpeg|png|gif|heic|JPG|PNG|HEIC)$ ]]; then
  echo -e "[ENGINE] IMAGE: Voyage Engine v1.7 Active..."
  VF="fps=$FPS,scale=w=5120:h=2880:force_original_aspect_ratio=increase,crop=5120:2880,zoompan=z='if(mod(floor(on/$SDUR),2), 1.1+(1.4-1.1)*(mod(on,$SDUR)/$SDUR), 1.4-(1.4-1.1)*(mod(on,$SDUR)/$SDUR))':x='trunc((iw-iw/zoom)*(if(lt(on,$SDUR), 0.5-0.4*(on/$SDUR), if(gt(on,$END_START), 0.1+0.4*((on-$END_START)/$SDUR), if(eq(mod(floor(on/$SDUR),4),1), 0.1+0.8*(mod(on,$SDUR)/$SDUR), if(eq(mod(floor(on/$SDUR),4),2), 0.9, if(eq(mod(floor(on/$SDUR),4),3), 0.9-0.8*(mod(on,$SDUR)/$SDUR), 0.1)))))))':y='trunc((ih-ih/zoom)*(if(lt(on,$SDUR), 0.5-0.4*(on/$SDUR), if(gt(on,$END_START), 0.1+0.4*((on-$END_START)/$SDUR), if(eq(mod(floor(on/$SDUR),4),1), 0.1, if(eq(mod(floor(on/$SDUR),4),2), 0.1+0.8*(mod(on,$SDUR)/$SDUR), if(eq(mod(floor(on/$SDUR),4),3), 0.9, 0.9-0.8*(mod(on,$SDUR)/$SDUR))))))))':d=1:s=1920x1080:fps=$FPS,${SUB_FILTER}"
  IN_FLAGS="-loop 1 -i"
else
  echo -e "[ENGINE] VIDEO: Bypassing Voyage (Native Motion)..."
  VF="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=$FPS,${SUB_FILTER}"
  IN_FLAGS="-stream_loop -1 -i"
fi

# PASS 1: LYRICS (Vocal + Backing)
echo -e "[ENGINE] Rendering LYRICS MP4..."
ffmpeg -y $IN_FLAGS "$BG_PATH" -i "$AUDIO_1" -i "$AUDIO_2" \
  -filter_complex "[0:v]${VF}[vout];[1:a][2:a]amix=inputs=2:duration=first[aout]" \
  -map "[vout]" -map "[aout]" -c:v libx264 -crf "$CRF" -preset medium -pix_fmt yuv420p -r "$FPS" -c:a aac -b:a 192k -shortest -t "$TOTAL_DUR" "$LYRICS_OUT"

# PASS 2: KARAOKE (Backing Only)
echo -e "[ENGINE] Rendering KARAOKE MP4..."
ffmpeg -y $IN_FLAGS "$BG_PATH" -i "$AUDIO_2" \
  -filter_complex "[0:v]${VF}[vout]" \
  -map "[vout]" -map 1:a -c:v libx264 -crf "$CRF" -preset medium -pix_fmt yuv420p -r "$FPS" -c:a aac -b:a 192k -shortest -t "$TOTAL_DUR" "$KARAOKE_OUT"

rm "$TEMP_ASS"