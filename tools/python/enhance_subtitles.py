#!/usr/bin/env python3
import os
import json
import re
import subprocess
from datetime import datetime, timedelta

# --- Configuration Constants ---
PRESETS_FILE = "assets.json"
GAP_THRESHOLD_SECONDS = 8.0  # Minimum gap length to register an internal instrumental interlude

def parse_time(time_str):
    """Converts SRT timestamp string (HH:MM:SS,mmm) to a timedelta object."""
    time_str = time_str.replace('.', ',')
    match = re.match(r"(\d+):(\d+):(\d+),(\d+)", time_str)
    if match:
        hrs, mins, secs, ms = map(int, match.groups())
        return timedelta(hours=hrs, minutes=mins, seconds=secs, milliseconds=ms)
    return timedelta()

def format_time(td):
    """Converts a timedelta object back into a standard SRT timestamp."""
    total_seconds = int(td.total_seconds())
    hrs = total_seconds // 3600
    mins = (total_seconds % 3600) // 60
    secs = total_seconds % 60
    ms = int(td.microseconds / 1000)
    return f"{hrs:02d}:{mins:02d}:{secs:02d},{ms:03d}"

def enhance_subtitles():
    print("🔍 =========================================================")
    print("   AUTOMATED SUBTITLE TRACK TIMELINE ANALYZER & ENHANCER")
    print("   =========================================================\n")

    # 1. Load project tracking layout configuration metadata
    if not os.path.exists(PRESETS_FILE):
        print(f"❌ Error: Config file '{PRESETS_FILE}' not found in current workspace context.")
        return

    with open(PRESETS_FILE, 'r', encoding='utf-8') as f:
        config = json.load(f)

    rel_srt = config.get("inputs", {}).get("subtitles", "")
    if not rel_srt or not os.path.exists(rel_srt):
        print(f"❌ Error: Target subtitle path '{rel_srt}' missing or unavailable.")
        return

    # Extract base track metadata names dynamically
    song_title = config.get("inputs", {}).get("song_title", "")
    song_author = config.get("inputs", {}).get("song_author", "")

    if not song_title:
        # Fallback default: strip name from file name base
        song_title = os.path.splitext(os.path.basename(rel_srt))[0].replace("-", " ")
    
    print(f"📁 Active Subtitle Source: {rel_srt}")
    print(f"🎵 Active Registered Song: {song_title}")
    
    # Prompt for metadata entry updating if needed
    print("\n📝 Verify Title Card Details:")
    user_title = input(f"   Enter Song Title [{song_title}]: ").strip() or song_title
    user_author = input(f"   Enter Song Author/Composer [{song_author if song_author else 'Unknown'}]: ").strip() or song_author
    
    # Save back variables instantly to sync configuration matrix
    config["inputs"]["song_title"] = user_title
    config["inputs"]["song_author"] = user_author
    with open(PRESETS_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)

    # 2. Ingest and parse raw SRT chunks
    with open(rel_srt, 'r', encoding='utf-8') as f:
        raw_content = f.read().replace('\r\n', '\n').strip()

    # Split cleanly by double lines to isolate subtitle blocks
    blocks = [b.strip() for b in raw_content.split('\n\n') if b.strip()]
    parsed_subs = []

    for block in blocks:
        lines = [l.strip() for l in block.split('\n') if l.strip()]
        if len(lines) >= 3:
            time_line = lines[1]
            time_match = re.match(r"(\d+:\d+:\d+[,.]\d+)\s*-->\s*(\d+:\d+:\d+[,.]\d+)", time_line)
            if time_match:
                start_td = parse_time(time_match.group(1))
                end_td = parse_time(time_match.group(2))
                text_content = "\n".join(lines[2:])
                parsed_subs.append({"start": start_td, "end": end_td, "text": text_content})

    if not parsed_subs:
        print("❌ Error: Could not extract valid timing index lines from file.")
        return

    # Sort array explicitly by timeline timestamps to handle anomalies safely
    parsed_subs.sort(key=lambda x: x["start"])

    # 3. Analyze Timeline Framework Gaps (With Intro, Interlude, and Outro Detection)
    injections = []
    
    # Check intro sequence timeline window block
    first_vocal_start = parsed_subs[0]["start"]
    if first_vocal_start.total_seconds() > 4.0:
        injections.append({
            "type": "INTRO",
            "start": timedelta(seconds=0),
            "end": timedelta(seconds=7),  # Fixed 7-second reading comfort length
            "text": f"[Title] {user_title}\n[Author] {user_author}"
        })

    # Check interludes inside block boundaries
    for i in range(len(parsed_subs) - 1):
        current_end = parsed_subs[i]["end"]
        next_start = parsed_subs[i+1]["start"]
        gap_duration = (next_start - current_end).total_seconds()

        if gap_duration >= GAP_THRESHOLD_SECONDS:
            # Build smart safety offsets around the interlude string
            interlude_start = current_end + timedelta(seconds=1.5)
            interlude_end = next_start - timedelta(seconds=2.0)
            
            # Ensure safety boundaries don't invert timing logic on short gaps
            if interlude_end > interlude_start:
                injections.append({
                    "type": "INTERLUDE",
                    "start": interlude_start,
                    "end": interlude_end,
                    "text": "[Interlude]"
                })

    # Check trailing empty gap at the end for the Outro Section
    rel_bg = config.get("inputs", {}).get("background", "")
    if rel_bg and os.path.exists(rel_bg):
        try:
            cmd = f"ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"{rel_bg}\""
            total_duration_secs = float(subprocess.check_output(cmd, shell=True).decode().strip())
            total_duration_td = timedelta(seconds=total_duration_secs)
            
            last_vocal_end = parsed_subs[-1]["end"]
            outro_gap = (total_duration_td - last_vocal_end).total_seconds()
            
            # If there are more than 6 seconds of trailing music left, inject an Outro block
            if outro_gap >= 6.0:
                outro_start = last_vocal_end + timedelta(seconds=1.5)
                # Clear the text 2 seconds before the file completely terminates
                outro_end = total_duration_td - timedelta(seconds=2.0) 
                
                if outro_end > outro_start:
                    injections.append({
                        "type": "OUTRO",
                        "start": outro_start,
                        "end": outro_end,
                        "text": "[Outro]"
                    })
        except Exception as e:
            # Silent fallback if background file cannot be resolved via ffprobe
            pass

    # 4. Interactive Confirmation Terminal Summary Console Display
    print("\n📊 =========================================================")
    print(f"   TIMELINE ANALYSIS REPORT: Found {len(injections)} structural gap(s)")
    print("   =========================================================")
    
    accepted_injections = []
    for idx, inj in enumerate(injections, start=1):
        start_str = format_time(inj["start"])
        end_str = format_time(inj["end"])
        
        print(f"\n⚡ [{idx}] Detected Structural Gap Mode: {inj['type']}")
        print(f"   ⏱️  Time window block: {start_str} --> {end_str}")
        print(f"   📝 Text Content to Inject:\n{inj['text']}")
        
        confirm = input("   Accept this injection sequence update? (Y/n): ").strip().lower() or 'y'
        if confirm == 'y':
            accepted_injections.append(inj)
            print("   ✅ Queued for processing.")
        else:
            print("   ⏭️  Skipped.")

    # 5. Compile and output Enhanced Master Subtitle File
    if not accepted_injections:
        print("\n⏭️  No optimization changes chosen. Output file unchanged.")
        return

    # Merge original segments with new structural frames
    master_timeline = parsed_subs + accepted_injections
    master_timeline.sort(key=lambda x: x["start"])

    # Output back out using exact standardized SRT layout formats
    with open(rel_srt, 'w', encoding='utf-8') as f:
        for block_idx, item in enumerate(master_timeline, start=1):
            start_str = format_time(item["start"])
            end_str = format_time(item["end"])
            f.write(f"{block_idx}\n")
            f.write(f"{start_str} --> {end_str}\n")
            f.write(f"{item['text']}\n\n")

    print("\n💾 =========================================================")
    print("   SUCCESS: Timeline modification layers merged completely!")
    print(f"   Target path updated: '{rel_srt}'")
    print("   =========================================================\n")

if __name__ == "__main__":
    enhance_subtitles()