import sys
import os
import mido

def parse_strict_text_lines(midi_path, txt_path):
    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    current_tempo = 500000
    raw_notes_pool = []
    
    for track in mid.tracks:
        absolute_ticks = 0
        for idx, msg in enumerate(track):
            absolute_ticks += msg.time
            if msg.is_meta and msg.type == 'set_tempo':
                current_tempo = msg.tempo
            if msg.type == 'note_on' and msg.velocity > 0:
                note_start_ms = ticks_to_ms(absolute_ticks, ticks_per_beat, current_tempo)
                note_duration_ticks = 0
                search_ticks = absolute_ticks
                for downstream_msg in track[idx+1:]:
                    search_ticks += downstream_msg.time
                    if (downstream_msg.type == 'note_off' and downstream_msg.note == msg.note) or \
                       (downstream_msg.type == 'note_on' and downstream_msg.note == msg.note and downstream_msg.velocity == 0):
                        note_duration_ticks = search_ticks - absolute_ticks
                        break
                note_end_ms = note_start_ms + ticks_to_ms(note_duration_ticks, ticks_per_beat, current_tempo)
                duration_cs = int((note_end_ms - note_start_ms) / 10)
                raw_notes_pool.append({'start_ms': note_start_ms, 'duration_cs': duration_cs})
                
    raw_notes_pool.sort(key=lambda x: x['start_ms'])
    
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
                        data = {**raw_notes_pool[note_pointer], 'lyric': word}
                        note_pointer += 1
                        current_phrase.append(data)
                if current_phrase:
                    phrases.append(current_phrase)
    return phrases
