#!/usr/bin/env python3
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Option 5 Python Timing Extraction Library
# Script: tools/python/extract_dialogue.py
# Purpose: Core library for MIDI note-to-text timing extraction.
# 
# Summary:
#   This library serves as the engine for parsing MIDI event ticks and 
#   external text lyric files into timestamped phrase objects.
#
# Why we need the Text File:
#   1. Encoding Bridge: MIDI files contain raw byte data that often fails 
#      Vietnamese font rendering. The text file (UTF-8) provides a clean, 
#      consistent source for lyrics.
#   2. Structure Mapping: The MIDI file contains the "Timing Data" (when to play), 
#      while the text file provides the "Lyrics" (what to display). By 
#      combining them, we ensure the lyrics are formatted with your 
#      preferred font styles without relying on the MIDI file's metadata.
#
# Inputs:
#   - midi_path (str): Filesystem path to the MIDI source.
#   - txt_path (str): Filesystem path to the lyric text file (for fonts/lyrics).
# ==============================================================================

import sys, os, mido

def format_ass_time(ms):
    """Converts milliseconds to .ass format: H:MM:SS.cc"""
    # Use // for integer division to ensure we get integers, not floats
    total_cs = int(ms // 10)
    h = total_cs // 360000
    m = (total_cs // 6000) % 60
    s = (total_cs // 100) % 60
    cs = total_cs % 100
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"

def ticks_to_ms(ticks, ticks_per_beat, current_tempo):
    return (ticks * current_tempo) / ticks_per_beat / 1000.0

def parse_strict_text_lines(midi_path, txt_path):
    """Parses MIDI for timing and maps them to words from the text file."""
    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    current_tempo = 500000
    raw_notes_pool = []
    
    # Extract timing data from MIDI
    for track in mid.tracks:
        abs_ticks = 0
        for idx, msg in enumerate(track):
            abs_ticks += msg.time
            if msg.is_meta and msg.type == 'set_tempo': 
                current_tempo = msg.tempo
            if msg.type == 'note_on' and msg.velocity > 0:
                start_ms = ticks_to_ms(abs_ticks, ticks_per_beat, current_tempo)
                dur_ticks = 0
                search_ticks = abs_ticks
                for d_msg in track[idx+1:]:
                    search_ticks += d_msg.time
                    if (d_msg.type == 'note_off' and d_msg.note == msg.note) or \
                       (d_msg.type == 'note_on' and d_msg.note == msg.note and d_msg.velocity == 0):
                        dur_ticks = search_ticks - abs_ticks
                        break
                # Ensure we store the duration in centiseconds as expected by the compiler
                duration_ms = ticks_to_ms(dur_ticks, ticks_per_beat, current_tempo)
                raw_notes_pool.append({
                    'start_ms': start_ms, 
                    'duration_cs': int(duration_ms / 10)
                })

    raw_notes_pool.sort(key=lambda x: x['start_ms'])
    
    # Map lyrics from text file
    phrases = []
    note_pointer = 0
    if os.path.exists(txt_path):
        with open(txt_path, 'r', encoding='utf-8') as f:
            for line in f:
                stripped = line.strip()
                if not stripped or stripped.startswith('['): continue
                line_words = stripped.split()
                current_phrase = []
                for word in line_words:
                    if note_pointer < len(raw_notes_pool):
                        # Constructing the note object that the compiler expects
                        data = {**raw_notes_pool[note_pointer], 'lyric': word}
                        note_pointer += 1
                        current_phrase.append(data)
                if current_phrase: 
                    phrases.append(current_phrase)
    return phrases

if __name__ == '__main__':
    # Debug mode to verify timing
    if len(sys.argv) >= 3:
        phrases = parse_strict_text_lines(sys.argv[1], sys.argv[2])
        for i, phrase in enumerate(phrases):
            for note in phrase:
                print(f"Word: {note['lyric']} | Start: {note['start_ms']:.0f}ms | Dur: {note['duration_cs']*10}ms")