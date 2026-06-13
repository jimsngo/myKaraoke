#!/usr/bin/env python3
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Raw Manifest Generator
# ==============================================================================

import os
import sys
from extract_dialogue import parse_strict_text_lines, format_ass_time

# Paths retrieved directly from Dashboard export
MIDI = os.environ.get('MIDI_FILE')
TXT  = os.environ.get('SUBTITLES_TXT')
OUT  = os.environ.get('SUBTITLES_ASS')

# Global Metadata from Karaoke_Dashboard.sh exports
SONG_TITLE = os.environ.get('SONG_TITLE', 'Unknown Title')
SONG_AUTHOR = os.environ.get('SONG_AUTHOR', 'Unknown Author')
INTRO_DURATION = 5000  # 5 seconds in milliseconds

def write_manifest():
    # Strict validation of dashboard inputs
    if not MIDI or not TXT or not OUT:
        print("❌ ERROR: Missing environment paths (MIDI_FILE, SUBTITLES_TXT, or SUBTITLES_ASS)")
        sys.exit(1)

    # Parse notes and map them directly using the text file as the structure link
    phrases = parse_strict_text_lines(MIDI, TXT)
    
    with open(OUT, 'w', encoding='utf-8') as f:
        # Header configuration matching your saved Aegisub workspace requirements
        f.write("[Script Info]\nScriptType: v4.00+\nPlayResX: 1280\nPlayResY: 720\n\n")
        f.write("[V4+ Styles]\n")
        f.write("Style: Title,Arial,80,&H00FFFFFF&,&H000000FF&,0,0,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1\n")
        f.write("Style: Lyrics,Arial,60,&H00FFFFFF&,&H000000FF&,0,0,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1\n\n")
        f.write("[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")
        
        # 1. Title/Author Intro Screen (Uses Title Style, scales Author font down to size 50)
        f.write(f"Dialogue: 0,0:00:00.00,{format_ass_time(INTRO_DURATION)},Title,,0,0,0,,{SONG_TITLE}\\N{{\\fs50}}{SONG_AUTHOR}\n")
        
        # 2. Synchronized Lyrics Execution (Uses Lyrics Style explicitly)
        for phrase in phrases:
            # Timing is anchored strictly to note-on of first word and note-off of last word
            start_time = phrase[0]['start_ms']
            end_time = phrase[-1]['start_ms'] + (phrase[-1]['duration_cs'] * 10)
            
            # Reconstruct the text line with explicit \k tags to lock individual word durations
            karaoke_text = ""
            for note in phrase:
                duration_cs = int(note['duration_cs'])
                karaoke_text += f"{{\\k{duration_cs}}}{note['lyric']} "
            
            # Correctly assigned style field to Lyrics
            f.write(f"Dialogue: 0,{format_ass_time(start_time)},{format_ass_time(end_time)},Lyrics,,0,0,0,,{karaoke_text.strip()}\n")

if __name__ == '__main__':
    write_manifest()
    print(f"✅ Clean raw manifest generated via environment variables to: {OUT}")