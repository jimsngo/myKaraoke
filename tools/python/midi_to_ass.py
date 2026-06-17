#!/usr/bin/env python3
import os
import sys
import json
import mido

MIDI_ENV = os.environ.get("MIDI_FILE")
OUT_ENV  = os.environ.get("SUBTITLES_ASS")
INTRO_DURATION = 5000

# Hardcoded Production Color Profiles (ASS Format: &HBBGGRR&)
COLOR_WHITE = "&H00FFFFFF&"
COLOR_BLACK = "&H00000000&"
COLOR_BLUE  = "&H00DE7B1A&"  # High-fidelity Royal Blue for Male
COLOR_PINK  = "&H00B469FF&"  # High-fidelity Vibrant Pink for Female

# Load metadata variables directly from master assets json configuration blueprint
ASSETS_PATH = "/Users/jim/myKaraoke/assets.json"
try:
    with open(ASSETS_PATH, "r", encoding="utf-8") as f:
        config = json.load(f)
    SONG_TITLE = config["inputs"].get("song_title", "Unknown Title")
    SONG_AUTHOR = config["inputs"].get("song_author", "Unknown Author")
    GENDER_SELECTION = config["inputs"].get("vocalist_gender", "Male")
    raw_bpm = config["inputs"].get("midi_bpm", "70.0")
    MIN_WORD_DURATION = float(config.get("settings", {}).get("min_word_duration", 0.10))
except Exception as e:
    SONG_TITLE = os.environ.get("SONG_TITLE", "Unknown Title")
    SONG_AUTHOR = os.environ.get("SONG_AUTHOR", "Unknown Author")
    GENDER_SELECTION = "Male"
    raw_bpm = os.environ.get("MIDI_BPM", "70.0")
    MIN_WORD_DURATION = 0.10

try: BPM = float(raw_bpm)
except ValueError: BPM = 70.0

BEAT_DURATION = 60.0 / BPM
LEAD_IN_SECONDS = 2.0 * BEAT_DURATION
START_BAR = 10
BAR_DURATION = 4.0 * BEAT_DURATION
TARGET_FIRST_NOTE_TIME = (START_BAR - 1) * BAR_DURATION

# Determine Gender Color Mode instantly from blueprint configuration
GENDER_COLOR = COLOR_PINK if GENDER_SELECTION.strip().lower() == "female" else COLOR_BLUE

def format_to_ass_time(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    centiseconds = int(round((seconds % 1) * 100))
    if centiseconds == 100:
        secs += 1
        centiseconds = 0
    return f"{hours:01d}:{minutes:02d}:{secs:02d}.{centiseconds:02d}"

def extract_syllables_from_midi(midi_path):
    if not os.path.exists(midi_path):
        print(f"❌ ERROR: MIDI file '{midi_path}' not found.")
        sys.exit(1)

    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    
    tempo_changes = [{"tick": 0, "tempo": 500000}]
    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            if msg.type == "set_tempo":
                tempo_changes.append({"tick": abs_tick, "tempo": msg.tempo})
    tempo_changes.sort(key=lambda x: x["tick"])

    def get_seconds_from_ticks(target_tick):
        seconds = 0.0
        current_tick = 0
        current_tempo = 500000
        for change in tempo_changes:
            if target_tick > change["tick"]:
                duration_ticks = change["tick"] - current_tick
                seconds += mido.tick2second(duration_ticks, ticks_per_beat, current_tempo)
                current_tick = change["tick"]
                current_tempo = change["tempo"]
            else: break
        remaining_ticks = target_tick - current_tick
        seconds += mido.tick2second(remaining_ticks, ticks_per_beat, current_tempo)
        return seconds

    tokens = []
    for track in mid.tracks:
        abs_tick = 0
        pending_lyrics = []
        active_notes = {}

        for msg in track:
            abs_tick += msg.time
            if msg.type in ["lyrics", "text"]:
                try: raw_txt = msg.text.encode("latin1").decode("utf-8")
                except: raw_txt = msg.text

                card_break = "//" in raw_txt
                line_break = "/" in raw_txt and not card_break
                clean_text = raw_txt.replace("//", "").replace("/", "").strip()
                
                if clean_text == "":
                    if pending_lyrics:
                        if card_break: pending_lyrics[-1]["card_break"] = True
                        if line_break: pending_lyrics[-1]["line_break"] = True
                    elif tokens:
                        if card_break: tokens[-1]["card_break"] = True
                        if line_break: tokens[-1]["line_break"] = True
                    continue

                clean_text = " " + clean_text

                pending_lyrics.append({
                    "tick": abs_tick, 
                    "text": clean_text,
                    "line_break": line_break,
                    "card_break": card_break
                })
            elif msg.type == "note_on" and msg.velocity > 0:
                active_notes[msg.note] = abs_tick
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                if msg.note in active_notes:
                    start_tick = active_notes[msg.note]
                    end_tick = abs_tick
                    del active_notes[msg.note]
                    if pending_lyrics:
                        lyric_token = pending_lyrics.pop(0)
                        tokens.append({
                            "text": lyric_token["text"],
                            "raw_start": get_seconds_from_ticks(start_tick),
                            "raw_end": get_seconds_from_ticks(end_tick),
                            "line_break": lyric_token["line_break"],
                            "card_break": lyric_token["card_break"]
                        })
    
    tokens.sort(key=lambda x: x["raw_start"])
    if not tokens: return []

    raw_first_note_time = tokens[0]["raw_start"]
    sync_offset = TARGET_FIRST_NOTE_TIME - raw_first_note_time

    calibrated_tokens = []
    for t in tokens:
        calibrated_tokens.append({
            "text": t["text"],
            "start_time": t["raw_start"] + sync_offset,
            "end_time": t["raw_end"] + sync_offset,
            "line_break": t["line_break"],
            "card_break": t["card_break"]
        })
    return calibrated_tokens

def compile_ass_file(raw_tokens, out_path):
    cards = []
    current_card_tokens = []
    
    for token in raw_tokens:
        current_card_tokens.append(token)
        if token["card_break"]:
            cards.append({
                "tokens": current_card_tokens,
                "true_start": current_card_tokens[0]["start_time"],
                "true_end": current_card_tokens[-1]["end_time"],
                "last_word_start": current_card_tokens[-1]["start_time"]
            })
            current_card_tokens = []
            
    if current_card_tokens:
        cards.append({
            "tokens": current_card_tokens,
            "true_start": current_card_tokens[0]["start_time"],
            "true_end": current_card_tokens[-1]["end_time"],
            "last_word_start": current_card_tokens[-1]["start_time"]
        })

    for i in range(len(cards)):
        cards[i]["screen_start"] = max(0.0, cards[i]["true_start"] - LEAD_IN_SECONDS)
        cards[i]["screen_end"] = cards[i]["true_end"] + 0.4

    for i in range(1, len(cards)):
        prev = cards[i-1]
        curr = cards[i]
        desired_curr_start = curr["true_start"] - LEAD_IN_SECONDS
        
        if desired_curr_start < prev["screen_end"]:
            min_start = prev["tokens"][-1]["start_time"] + MIN_WORD_DURATION + 0.02  
            max_start = curr["true_start"] - 0.04               
            curr["screen_start"] = min(max_start, max(min_start, desired_curr_start))
            prev["screen_end"] = curr["screen_start"] - 0.02
            
            if prev["screen_end"] < prev["true_end"]:
                prev["tokens"][-1]["end_time"] = prev["screen_end"]
                prev["true_end"] = prev["screen_end"]
        else:
            prev["screen_end"] = min(prev["true_end"] + 1.0, desired_curr_start - 0.02)
            curr["screen_start"] = desired_curr_start

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("[Script Info]\nScriptType: v4.00+\nPlayResX: 1280\nPlayResY: 720\n\n")
        f.write("[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n")
        f.write(f"Style: Title,Arial,80,{GENDER_COLOR},{GENDER_COLOR},{COLOR_BLACK},{COLOR_BLACK},1,0,0,0,100,100,0,0,1,3,2,5,10,10,10,1\n")
        f.write(f"Style: Lyrics,Arial,60,{COLOR_WHITE},{GENDER_COLOR},{COLOR_BLACK},{COLOR_BLACK},1,0,0,0,100,100,0,0,1,3,1,2,10,10,25,1\n\n")
        
        f.write("[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")
        
        # Auto-Resizing Title Card Logic
        final_title_size = 80
        final_author_size = 50
        if len(SONG_TITLE) >= 18:
            final_title_size = max(40, int(80 * (16 / len(SONG_TITLE))))
        if len(SONG_AUTHOR) >= 28:
            final_author_size = max(28, int(50 * (24 / len(SONG_AUTHOR))))

        intro_end = INTRO_DURATION / 1000.0
        f.write(f"Dialogue: 0,0:00:00.00,{format_to_ass_time(intro_end)},Title,,0,0,0,,{{\\fs{final_title_size}}}{SONG_TITLE}\\N{{\\fs{final_author_size}}}{SONG_AUTHOR}\n")
        
        # 🎯 TARGET REMOVAL: Phase 1 Intro Check has been completely removed. Title card owns the space.

        for idx, card in enumerate(cards):
            actual_lead_in = card['true_start'] - card['screen_start']
            lead_in_cs = int(round(actual_lead_in * 100))
            
            payload_string = ""
            if lead_in_cs > 0:
                payload_string += f"{{\\k{lead_in_cs}}}\\h"
            
            total_words = len(card['tokens'])
            for w_idx, token in enumerate(card['tokens']):
                duration_cs = int(round((token['end_time'] - token['start_time']) * 100))
                
                if w_idx == 0:
                    clean_first_word = token['text'].lstrip()
                    payload_string += f"{{\\k{duration_cs}}}{clean_first_word}"
                elif w_idx > 0 and card['tokens'][w_idx - 1]['line_break']:
                    payload_string += f"\\N{{\\k{duration_cs}}}{token['text'].strip()}"
                else:
                    payload_string += f"{{\\k{duration_cs}}}{token['text']}"
                
                if w_idx < total_words - 1:
                    next_tok = card['tokens'][w_idx + 1]
                    gap = next_tok['start_time'] - token['end_time']
                    if gap > 0.005:
                        gap_cs = int(round(gap * 100))
                        if gap_cs > 0:
                            payload_string += f"{{\\k{gap_cs}}}"

            trailing_silence = card['screen_end'] - card['true_end']
            trailing_cs = int(round(trailing_silence * 100))
            if trailing_cs > 0:
                payload_string += f"{{\\k{trailing_cs}}}\\h"

            f.write(f"Dialogue: 0,{format_to_ass_time(card['screen_start'])},{format_to_ass_time(card['screen_end'])},Lyrics,,0,0,0,,{payload_string.strip()}\n")
            
            # 🎯 TARGET UPDATE: Phase 2 Mid-Song Interlude Check with clean 1-bar margins
            if idx < len(cards) - 1:
                next_card = cards[idx + 1]
                musical_gap = next_card["true_start"] - card["true_end"]
                if musical_gap >= 4.0 * BAR_DURATION:
                    # Apply a 1-bar margin padding immediately after the vocal ends and before the next starts
                    int_start = card["true_end"] + BAR_DURATION
                    int_end = next_card["true_start"] - BAR_DURATION
                    if int_end > int_start + 1.0:
                        f.write(f"Dialogue: 0,{format_to_ass_time(int_start)},{format_to_ass_time(int_end)},Title,,0,0,0,,[Interlude]\n")
                        
    print(f"✅ Generated ASS file with 1-Bar Margin [Interlude] Engine active: {out_path}")

if __name__ == "__main__":
    if not MIDI_ENV:
        print("❌ ERROR: MIDI_FILE environment variable is not set.")
        sys.exit(1)

    if not OUT_ENV:
        base_name = os.path.splitext(os.path.basename(MIDI_ENV))[0]
        out_path = os.path.join("inputs", "subtitles", f"{base_name}.ass")
    else:
        out_path = OUT_ENV

    tokens = extract_syllables_from_midi(MIDI_ENV)
    compile_ass_file(tokens, out_path)
