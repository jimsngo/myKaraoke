#!/usr/bin/env python3
import sys, os, mido

def extract_midi_lyrics(midi_path):
    if not os.path.exists(midi_path):
        print(f"❌ ERROR: File not found: {midi_path}")
        return

    mid = mido.MidiFile(midi_path)
    print(f"🔍 Analyzing MIDI for lyrics: {midi_path}\n")
    print(f"{'Time (ms)':<12} | {'Lyric'}")
    print("-" * 30)

    for track in mid.tracks:
        for msg in track:
            if msg.is_meta and (msg.type == 'lyrics' or msg.type == 'text'):
                # THAY ĐỔI Ở ĐÂY:
                # Thử giải mã từ 'latin-1' (thường dùng trong MIDI cũ) sang utf-8
                try:
                    raw_text = msg.text
                    # Dùng 'latin-1' để giữ nguyên ký tự, sau đó chuyển sang chuẩn hiển thị
                    decoded_text = raw_text.encode('latin-1').decode('utf-8', errors='ignore')
                except:
                    # Nếu lỗi, giữ nguyên văn bản gốc
                    decoded_text = msg.text
                
                print(f"{'N/A':<12} | {decoded_text}")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        extract_midi_lyrics(sys.argv[1])
    else:
        print("Usage: python3 extract_midi_lyrics.py <midi_path>")