#!/usr/bin/env python3
import sys
import os
import mido

def scan_raw_midi(midi_path):
    print("\n========================================================")
    print("🔬 DEEP BINARY MIDI PORT SCANNER")
    print(f"📂 Target File: {midi_path}")
    print("========================================================")
    
    if not os.path.exists(midi_path):
        print(f"❌ Error: File not found at {midi_path}")
        return

    try:
        mid = mido.MidiFile(midi_path)
    except Exception as e:
        print(f"❌ Error parsing file structure: {e}")
        return

    print(f"📊 File Format Type: {mid.type}")
    print(f"📊 Global Pulses Per Quarter Note (Ticks): {mid.ticks_per_beat}")
    print(f"📊 Total Isolated Tracks Extracted: {len(mid.tracks)}\n")

    for idx, track in enumerate(mid.tracks):
        print(f"--- ANALYZING TRACK #{idx} ---")
        absolute_ticks = 0
        note_on_count = 0
        meta_event_count = 0
        text_samples = []

        for msg in track:
            absolute_ticks += msg.time
            
            # Catch every single meta-event to see what structure SynthV used
            if msg.is_meta:
                meta_event_count += 1
                # Capture any property that contains text/strings
                msg_dict = msg.dict()
                text_content = msg_dict.get('text', msg_dict.get('name', msg_dict.get('data', '')))
                
                if text_content:
                    text_samples.append((absolute_ticks, msg.type, str(text_content).strip()))

            elif msg.type in ('note_on', 'note_off'):
                if msg.type == 'note_on' and msg.velocity > 0:
                    note_on_count += 1
                    # Inspect if SynthV appended custom dict/attribute payload fields inside note parameters
                    msg_str = str(msg)
                    if any(x in msg_str for x in ['text', 'lyric', 'name']):
                        print(f"   📍 Found Attribute Payload inside Note Event at Tick {absolute_ticks}: {msg_str}")

        print(f"   🔹 Note_On Voices Detected: {note_on_count}")
        print(f"   🔹 Meta Events Detected: {meta_event_count}")
        
        if text_samples:
            print(f"   ✅ TEXT/META STRINGS DISCOVERED IN TRACK #{idx}:")
            for tick, msg_type, text in text_samples:
                print(f"     ▪️ Absolute Tick {tick:6d} | Type: {msg_type:15s} -> '{text}'")
        else:
            print(f"   ❌ No string fields found via standard types in Track #{idx}")
        print("-" * 56)

if __name__ == '__main__':
    # Target your local active session file directly
    target_file = "/Users/jim/myKaraoke/inputs/midi/Di-Vang-Nhat-Nhoa-Male.mid"
    scan_raw_midi(target_file)