#!/usr/bin/env python3
import sys
import os
import mido
import json

def ticks_to_ms(ticks, ticks_per_beat, current_tempo):
    return (ticks * current_tempo) / ticks_per_beat / 1000.0

def format_ass_time(ms):
    h = int(ms // 3600000)
    m = int((ms % 3600000) // 60000)
    s = int((ms % 60000) // 1000)
    cs = int((ms % 1000) // 10)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"

def format_srt_time(ms):
    h = int(ms // 3600000)
    m = int((ms % 3600000) // 60000)
    s = int((ms % 60000) // 1000)
    ms_part = int(ms % 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms_part:03d}"

def parse_strict_text_lines(midi_path, txt_path):
    print("\n⚡ RUNNING EXTRACTOR IN NATIVE AEGISUB MATCH MODE...")
    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    
    current_tempo = 500000
    time_sig = "4/4"        
    key_sig = "C"           
    bpm = 120.0             
    
    raw_notes_pool = []
    for track in mid.tracks:
        absolute_ticks = 0
        for idx, msg in enumerate(track):
            absolute_ticks += msg.time
            
            if msg.is_meta:
                if msg.type == 'set_tempo':
                    current_tempo = msg.tempo
                    bpm = round(mido.tempo2bpm(msg.tempo), 1)
                elif msg.type == 'time_signature':
                    time_sig = f"{msg.numerator}/{msg.denominator}"
                elif msg.type == 'key_signature':
                    key_sig = msg.key
            
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
                
                raw_notes_pool.append({
                    'start_ms': note_start_ms,
                    'end_ms': note_end_ms,
                    'duration_cs': duration_cs
                })
                
    raw_notes_pool.sort(key=lambda x: x['start_ms'])
    phrases = []
    note_pointer = 0
    
    if os.path.exists(txt_path):
        with open(txt_path, 'r', encoding='utf-8') as f:
            for line_idx, line in enumerate(f, 1):
                stripped = line.strip()
                if not stripped or stripped.startswith('['):
                    continue
                if stripped.lower() in ['dĩ vãng nhạt nhòa', 'dominic chow', 'khúc lan']:
                    continue
                
                line_words = stripped.split()
                current_phrase_line = []
                
                for word in line_words:
                    if note_pointer < len(raw_notes_pool):
                        note_data = raw_notes_pool[note_pointer].copy()
                        note_data['lyric'] = word
                        note_pointer += 1
                        current_phrase_line.append(note_data)
                    else:
                        note_data = {
                            'start_ms': phrases[-1][-1]['end_ms'] + 200 if phrases else 0,
                            'end_ms': phrases[-1][-1]['end_ms'] + 600 if phrases else 400,
                            'duration_cs': 40,
                            'lyric': word
                        }
                        current_phrase_line.append(note_data)
                
                if current_phrase_line:
                    phrases.append(current_phrase_line)
                    
    return phrases, time_sig, key_sig, bpm

def main(midi_path, output_ass_path):
    txt_path = midi_path.replace('inputs/midi/', 'inputs/text/').replace('.mid', '.txt')
    if not os.path.exists(txt_path):
        txt_path = os.path.splitext(midi_path)[0] + '.txt'
        
    config_path = os.path.join(os.path.dirname(txt_path), "config_styles.json")
    
    gender_mode = "Male"
    font_name = "Arial"
    song_title = "Dĩ Vãng Nhạt Nhòa"
    song_credits = "(Châu Đăng Khoa)" # Traditional style look
    res_x, res_y = 1280, 720 # Exact canvas boundary resolution match
    p_color, s_color = "&H00FFFFFF&", "&H00FF0000&"
    
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r', encoding='utf-8') as cfg_f:
                cfg = json.load(cfg_f)
                gender_mode = cfg["Track_Setup"]["Gender_Mode"]
                font_name = cfg["Track_Setup"]["Font_Name"]
                song_title = cfg["Song_Metadata"]["Title"]
                song_credits = cfg["Song_Metadata"]["Credits"]
                
                palette = cfg["Gender_Color_Palettes"].get(gender_mode, cfg["Gender_Color_Palettes"]["Male"])
                p_color = palette["PrimaryColour"].strip()
                s_color = palette["SecondaryColour"].strip()
        except Exception:
            pass

    phrases, time_sig, key_sig, bpm = parse_strict_text_lines(midi_path, txt_path)
    output_srt_path = output_ass_path.replace('.ass', '_synthv.srt')
    
    # Mirroring your working [V4+ Styles] layout completely
    ass_header = (
        "[Script Info]\n"
        "ScriptType: v4.00+\n"
        "WrapStyle: 0\n"
        "ScaledBorderAndShadow: yes\n"
        "YCbCr Matrix: None\n"
        f"PlayResX: {res_x}\n"
        f"PlayResY: {res_y}\n\n"
        "[V4+ Styles]\n"
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n"
        f"Style: Default,{font_name},48,&H00FFFFFF&,&H000000FF&,&H00000000&,&H00000000&,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1\n"
        f"Style: Title,{font_name},120,{s_color},{p_color},&H00FFFFFF&,&H00000000&,0,0,0,0,100,100,0,0,1,2,2,5,10,10,10,1\n"
        f"Style: Lyrics,{font_name},80,{p_color},{s_color},&H00000000&,&H00000000&,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1\n\n"
        "[Events]\n"
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
    )
    
    ass_lines = []
    srt_lines = []
    srt_counter = 1
    
    # Exact title entry replication style string
    ass_lines.append(f"Dialogue: 0,0:00:00.01,0:00:10.01,Title,,0,0,0,,{{\\fscx100\\fscy100\\b1}}{song_title}\\N\\N{{\\r\\fscx60\\fscy60\\i1}}{song_credits}")
    
    LONG_BREAK_THRESHOLD_MS = 15000  
    
    for idx, phrase in enumerate(phrases):
        phrase_start_ms = phrase[0]['start_ms']
        phrase_end_ms = phrase[-1]['end_ms']
        
        is_first_line = (idx == 0)
        has_long_interlude = False
        
        if not is_first_line:
            previous_phrase_end_ms = phrases[idx - 1][-1]['end_ms']
            silence_duration = phrase_start_ms - previous_phrase_end_ms
            if silence_duration >= LONG_BREAK_THRESHOLD_MS:
                has_long_interlude = True

        if is_first_line or has_long_interlude:
            display_start_ms = max(0, phrase_start_ms - 3500)
            gr_start = format_ass_time(display_start_ms)
            gr_end = format_ass_time(phrase_start_ms)
            ass_lines.append(f"Dialogue: 0,{gr_start},{gr_end},Default,,0,0,0,,🎤 Get Ready... ({time_sig} | {key_sig} | {bpm} BPM)")
            l_start_ms = display_start_ms
        else:
            l_start_ms = max(0, phrase_start_ms - 1500)

        l_start = format_ass_time(l_start_ms)
        l_end = format_ass_time(phrase_end_ms)
        
        karaoke_text = ""
        plain_text = ""
        
        # Calculate visual preparation lead cushion duration
        lead_in_cs = int((phrase_start_ms - l_start_ms) / 10)
        if lead_in_cs > 0:
            karaoke_text += f"{{\\k{lead_in_cs}}}"
            
        for note in phrase:
            # FIXED STRUCTURE: Native {\kXX}Tag followed immediately by the Word segment!
            karaoke_text += f"{{\\k{note['duration_cs']}}}{note['lyric']} "
            plain_text += f"{note['lyric']} "

        ass_lines.append(f"Dialogue: 1,{l_start},{l_end},Lyrics,,0,0,0,,{karaoke_text.strip()}")
        
        srt_start = format_srt_time(l_start_ms)
        srt_end = format_srt_time(phrase_end_ms)
        
        srt_lines.append(f"{srt_counter}")
        srt_lines.append(f"{srt_start} --> {srt_end}")
        srt_lines.append(f"{plain_text.strip()}\n")
        srt_counter += 1

    with open(output_ass_path, 'w', encoding='utf-8') as f:
        f.write(ass_header + "\n".join(ass_lines))
        
    with open(output_srt_path, 'w', encoding='utf-8') as f:
        f.write("\n".join(srt_lines))
        
    print(f"\n🎉 Native Aegisub format alignment output locked down!")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])