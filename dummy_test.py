#!/usr/bin/env python3
import sys
import os

# Add the lib folder to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'tools/python/lib'))

try:
    from extract_dialogue import parse_strict_text_lines
    print("✅ Library imported successfully.")
    
    midi_path = 'inputs/midi/Di-Vang-Nhat-Nhoa-Male.mid'
    # We pass None as the second argument since your library expects 2 arguments right now
    notes = parse_strict_text_lines(midi_path, None) 
    
    print(f"✅ Success! Extracted {len(notes)} notes.")
    print(f"   First note: {notes[0]}")
    
except Exception as e:
    print(f"❌ Test Failed: {e}")