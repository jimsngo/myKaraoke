#!/usr/bin/env python3
"""
Lightweight MIDI->ASS converter used in this repo. Reconstructed to repair a
corrupted file. Supports --char-scroll and --alternate-rows modes.
"""
import argparse
import json
import math
import os
import re
import sys
import unicodedata
from datetime import datetime

import mido
import shutil

# Project paths / defaults
ASSETS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets.json")
INTRO_DURATION = 5000

# Colors (ASS BGR hex: &HAABBGGRR& but we're using simplified values used previously)
COLOR_WHITE = "&H00FFFFFF&"
COLOR_BLACK = "&H00000000&"
COLOR_BLUE = "&H00DE7B1A&"  # male primary (approx)
COLOR_PINK = "&H00B469FF&"  # duet/female accent
COLOR_RED = "&H00FF0000&"   # female (past) red

# Load some inputs from assets.json when available
SONG_TITLE = "Unknown Title"
SONG_AUTHOR = "Unknown Author"
GENDER_SELECTION = "Male"
raw_target_bpm = "120.0"
try:
    with open(ASSETS_PATH, "r", encoding="utf-8") as fh:
        cfg = json.load(fh)
        SONG_TITLE = cfg.get("inputs", {}).get("song_title", SONG_TITLE)
        SONG_AUTHOR = cfg.get("inputs", {}).get("song_author", SONG_AUTHOR)
        GENDER_SELECTION = cfg.get("inputs", {}).get("vocalist_gender", GENDER_SELECTION)
        raw_target_bpm = cfg.get("inputs", {}).get("bpm", raw_target_bpm)
except Exception:
    pass

try:
    TARGET_BPM = float(raw_target_bpm)
except Exception:
    TARGET_BPM = 120.0

# Style tag parsing: allow lines like "1 = M" elsewhere but here we parse lyric inline tags
STYLE_TAG_RE = re.compile(r"^(?:#|@|\[)?\s*(?P<tag>female|male|f|m)(?:(?:\]|:)\s*|\s+)(?P<text>.*)$", re.I)

def parse_style_tag(raw_text):
    m = STYLE_TAG_RE.match(raw_text.strip())
    if not m:
        return None, raw_text
    tag = m.group("tag").lower()
    text = m.group("text").strip()
    if tag in ("f", "female"):
        return "female", text
    if tag in ("m", "male"):
        return "male", text
    return None, raw_text


# Tempo/time-signature helpers
def parse_tempo_events(mid: mido.MidiFile):
    events = []
    abs_tick = 0
    for msg in mid.tracks[0]:
        abs_tick += msg.time
        if msg.type == "set_tempo":
            events.append((abs_tick, msg.tempo))
    if not events:
        events = [(0, int(60000000 / TARGET_BPM))]
    return events


def parse_time_signatures(mid: mido.MidiFile):
    time_sigs = []
    abs_tick = 0
    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            if msg.type == "time_signature":
                time_sigs.append((abs_tick, msg.numerator, msg.denominator))
    if not time_sigs:
        time_sigs = [(0, 4, 4)]
    time_sigs.sort(key=lambda t: t[0])
    if time_sigs[0][0] != 0:
        time_sigs.insert(0, (0, time_sigs[0][1], time_sigs[0][2]))
    return time_sigs


def seconds_from_ticks(target_tick, ticks_per_beat, tempo_events):
    if target_tick <= 0:
        return 0.0
    total = 0.0
    cur_tick = 0
    cur_tempo = tempo_events[0][1]
    for ev_tick, tempo in tempo_events:
        if ev_tick > cur_tick and ev_tick <= target_tick:
            total += (ev_tick - cur_tick) * cur_tempo / ticks_per_beat / 1_000_000.0
            cur_tick = ev_tick
        cur_tempo = tempo
    if target_tick > cur_tick:
        total += (target_tick - cur_tick) * cur_tempo / ticks_per_beat / 1_000_000.0
    return total


# Extract lyric tokens aligned to note_on/note_off events
def extract_syllables_from_midi(midi_path):
    if not os.path.exists(midi_path):
        print(f"❌ ERROR: MIDI file '{midi_path}' not found.")
        sys.exit(1)

    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    tempo_events = parse_tempo_events(mid)

    def ticks_to_seconds(tick):
        return seconds_from_ticks(tick, ticks_per_beat, tempo_events)

    tokens = []
    for track in mid.tracks:
        abs_tick = 0
        pending_lyrics = []
        active_notes = {}
        for msg in track:
            abs_tick += msg.time
            if msg.type in ("lyrics", "text"):
                try:
                    raw_txt = msg.text.encode("latin1").decode("utf-8")
                except Exception:
                    try:
                        raw_txt = msg.text.encode("utf-8", errors="ignore").decode("utf-8")
                    except Exception:
                        raw_txt = str(msg.text)
                raw_txt = unicodedata.normalize("NFC", raw_txt)
                processed = re.sub(r"([^ ])/([^ ])", r"\1 / \2", raw_txt)
                style_tag, processed = parse_style_tag(processed)
                card_break = "/" in processed
                clean = processed.replace("/", "").strip()
                if clean == "":
                    # blank lyric (instrumental) - carry card break flags
                    if tokens and card_break:
                        tokens[-1]["card_break"] = True
                    continue
                clean = " " + clean
                pending_lyrics.append({
                    "tick": abs_tick,
                    "text": clean,
                    "card_break": card_break,
                    "style_tag": style_tag,
                })
            elif msg.type == "note_on" and msg.velocity > 0:
                note_key = (msg.channel, msg.note)
                if note_key in active_notes:
                    # overlapping; close previous range
                    prev_start = active_notes[note_key]["start_tick"]
                    if pending_lyrics:
                        lyric = pending_lyrics.pop(0)
                        tokens.append({
                            "text": lyric["text"],
                            "raw_start_tick": prev_start,
                            "raw_end_tick": abs_tick,
                            "start_time": ticks_to_seconds(prev_start),
                            "end_time": ticks_to_seconds(abs_tick),
                            "card_break": lyric["card_break"],
                            "style_tag": lyric.get("style_tag"),
                        })
                active_notes[note_key] = {"start_tick": abs_tick}
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                note_key = (msg.channel, msg.note)
                if note_key in active_notes:
                    start_tick = active_notes.pop(note_key)["start_tick"]
                    if pending_lyrics:
                        lyric = pending_lyrics.pop(0)
                        tokens.append({
                            "text": lyric["text"],
                            "raw_start_tick": start_tick,
                            "raw_end_tick": abs_tick,
                            "start_time": ticks_to_seconds(start_tick),
                            "end_time": ticks_to_seconds(abs_tick),
                            "card_break": lyric["card_break"],
                            "style_tag": lyric.get("style_tag"),
                        })
    tokens.sort(key=lambda t: t["start_time"])
    return tokens


def group_cards(raw_tokens, max_tokens=6):
    beat_duration = 60.0 / TARGET_BPM
    bar_duration = 4.0 * beat_duration
    cards = []
    current = []
    for i, tok in enumerate(raw_tokens):
        if current:
            gap = tok["start_time"] - current[-1]["end_time"]
            if current[-1]["card_break"] or gap >= bar_duration or len(current) >= max_tokens:
                cards.append({
                    "tokens": current,
                    "true_start": current[0]["start_time"],
                    "true_end": current[-1]["end_time"],
                    "style_tag": next((t.get("style_tag") for t in current if t.get("style_tag")), "default"),
                })
                current = []
        current.append(tok)
    if current:
        cards.append({
            "tokens": current,
            "true_start": current[0]["start_time"],
            "true_end": current[-1]["end_time"],
            "style_tag": next((t.get("style_tag") for t in current if t.get("style_tag")), "default"),
        })
    return cards


def group_logical_cards(raw_tokens):
    cards = []
    cur = []
    start_idx = 0
    for i, t in enumerate(raw_tokens):
        if not cur:
            start_idx = i
        cur.append(t)
        if t.get("card_break"):
            cards.append({"tokens": cur, "true_start": cur[0]["start_time"], "true_end": cur[-1]["end_time"], "start_token": start_idx+1, "end_token": i+1})
            cur = []
    if cur:
        cards.append({"tokens": cur, "true_start": cur[0]["start_time"], "true_end": cur[-1]["end_time"], "start_token": start_idx+1, "end_token": len(raw_tokens)})
    return cards


def estimate_card_font_size(card_text, base_size=55, max_width=1120, min_size=24):
    avg_char_width = 0.55
    text_length = len(card_text)
    width_at_base = text_length * base_size * avg_char_width
    if width_at_base <= max_width:
        return base_size, width_at_base
    scale = max_width / width_at_base
    candidate = int(max(min_size, round(base_size * scale)))
    return candidate, width_at_base


def write_styles_sidecar(cards, out_path, midi_path=None):
    try:
        base = os.path.splitext(out_path)[0]
        styles_path = base + ".styles.txt"
        default_gender = "M" if GENDER_SELECTION.strip().lower() != "female" else "F"
        with open(styles_path, "w", encoding="utf-8") as fh:
            fh.write("# Auto-generated styles sidecar from midi_to_ass.py\n")
            fh.write("# Edit this file and re-run to apply gender overrides.\n")
            fh.write(f"default = {default_gender}\n\n")
            for idx, card in enumerate(cards, start=1):
                tag = card.get("style_tag")
                fh.write(f"{idx} = {'F' if tag == 'female' else 'M'}\n")
        # copy to inputs/Subtitles
        inputs_dir = os.path.join(os.path.dirname(os.path.abspath(ASSETS_PATH)), "inputs", "Subtitles")
        os.makedirs(inputs_dir, exist_ok=True)
        shutil.copyfile(styles_path, os.path.join(inputs_dir, os.path.basename(styles_path)))
        print(f"📝 Wrote styles sidecar: {styles_path}")
    except Exception as e:
        print(f"⚠️ Failed to write styles sidecar: {e}")


def parse_styles_file(path):
    out = {}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    left, right = line.split("=", 1)
                    left = left.strip()
                    right = right.strip().lower()
                    if left == "default":
                        out[0] = "female" if right.startswith("f") else "male"
                    else:
                        try:
                            idx = int(left)
                            out[idx] = "female" if right.startswith("f") else "male"
                        except Exception:
                            pass
    except Exception:
        pass
    return out


def format_to_ass_time(sec):
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = sec % 60
    return f"0{h}:{m:02d}:{s:05.2f}"


def compile_ass_file(raw_tokens, out_path, styles_map=None, char_scroll=False, alternate_rows=False):
    cards = group_cards(raw_tokens)
    # apply styles_map carry-over
    if styles_map:
        previous = styles_map.get(0)
        for i, card in enumerate(cards, start=1):
            if i in styles_map:
                card["style_tag"] = styles_map[i]
            else:
                if card.get("style_tag"):
                    previous = card.get("style_tag")
                elif previous:
                    card["style_tag"] = previous
            if card.get("style_tag"):
                previous = card.get("style_tag")

    beat_duration = 60.0 / TARGET_BPM
    bar_duration = 4.0 * beat_duration

    # compute screen windows
    for i in range(len(cards)):
        curr = cards[i]
        if i == 0:
            curr["screen_start"] = max(0.0, curr["true_start"] - bar_duration)
        else:
            prev = cards[i - 1]
            gap = curr["true_start"] - prev["true_end"]
            if gap < bar_duration:
                curr["screen_start"] = prev["true_start"]
            else:
                curr["screen_start"] = curr["true_start"] - bar_duration
        curr["screen_end"] = curr["true_end"]

    # card metadata
    for card in cards:
        card_text = "".join([t["text"].strip() + " " for t in card["tokens"]]).strip()
        font_size, est_width = estimate_card_font_size(card_text)
        card["font_size"] = font_size
        card["estimated_width"] = est_width

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("[Script Info]\nScriptType: v4.00+\nPlayResX: 1280\nPlayResY: 720\n\n")
        f.write("[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n")
        FONT = "Arial"
        f.write(f"Style: Title,{FONT},72,{COLOR_BLUE},{COLOR_BLUE},{COLOR_BLACK},{COLOR_BLACK},0,0,0,0,100,100,0,0,1,2,1,5,10,10,10,1\n")
        f.write(f"Style: Row_Top_Left,{FONT},52,{COLOR_WHITE},{COLOR_WHITE},{COLOR_BLACK},{COLOR_BLACK},0,0,0,0,100,100,0,0,1,2,1,1,80,80,135,1\n")
        f.write(f"Style: Row_Bottom_Right,{FONT},52,{COLOR_WHITE},{COLOR_WHITE},{COLOR_BLACK},{COLOR_BLACK},0,0,0,0,100,100,0,0,1,2,1,3,80,80,65,1\n\n")
        f.write("[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")

        # title
        intro_end = INTRO_DURATION / 1000.0
        final_title_size = 80
        final_author_size = 50
        f.write(f"Dialogue: 0,0:00:00.00,{format_to_ass_time(intro_end)},Title,,0,0,0,,{{\\fs{final_title_size}}}{SONG_TITLE}\\N{{\\fs{final_author_size}}}{SONG_AUTHOR}\n")

        if not alternate_rows:
            current_row = "top"
            prev_gender = None
            for idx, card in enumerate(cards):
                lead_in_delta = card["true_start"] - card["screen_start"]
                lead_in_cs = int(round(lead_in_delta * 100))

                payload_k = ""
                payload_bg = ""
                # NO \h lead-in on Layer 1 — Layer 1 starts at true_start so the
                # hard-space offset doesn't mis-align it against Layer 0.
                if card.get("font_size", 52) != 52:
                    payload_k += f"{{\\fs{card['font_size']}}}"
                    payload_bg += f"{{\\fs{card['font_size']}}}"

                def plain_text_for(t):
                    return t.lstrip() if t.startswith(" ") else t

                total_words = len(card["tokens"])
                for w_idx, token in enumerate(card["tokens"]):
                    if w_idx == 0:
                        payload_bg += plain_text_for(token["text"])
                    else:
                        payload_bg += token["text"]

                    if char_scroll:
                        tok = token["text"].lstrip()
                        dur = (token["end_time"] - token["start_time"]) or 0.01
                        if len(tok) <= 1:
                            ch_durs = [dur]
                        else:
                            ch_durs = [dur / len(tok)] * len(tok)
                        for ci, ch in enumerate(tok):
                            cs = int(round(ch_durs[ci] * 100))
                            if cs <= 0:
                                cs = 1
                            payload_k += f"{{\\k{cs}}}{ch}"
                    else:
                        duration_cs = int(round((token["end_time"] - token["start_time"]) * 100))
                        if duration_cs <= 0:
                            duration_cs = 1
                        token_text = token["text"].lstrip() if w_idx == 0 else token["text"]
                        payload_k += f"{{\\k{duration_cs}}}{token_text}"

                    if w_idx < total_words - 1:
                        next_tok = card["tokens"][w_idx + 1]
                        gap = next_tok["start_time"] - token["end_time"]
                        if gap > 0.005:
                            gap_cs = int(round(gap * 100))
                            if gap_cs > 0:
                                payload_k += f"{{\\k{gap_cs}}}"

                assigned_style = "Row_Top_Left" if current_row == "top" else "Row_Bottom_Right"
                current_row = "bottom" if current_row == "top" else "top"

                # colors
                card_gender = card.get("style_tag") or "default"
                if card_gender == "female":
                    past_primary = COLOR_RED
                elif card_gender == "duet":
                    past_primary = COLOR_PINK
                else:
                    past_primary = COLOR_BLUE
                # \c = primary (sung color), \2c = secondary (unsung = white),
                # \3c = outline: keep BLACK so unsung Layer-1 is identical to
                # Layer-0 background (no visible overlap). Sung words still pop
                # in their gender color.
                past_override   = f"{{\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"
                future_override = f"{{\\c{COLOR_WHITE}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"

                prev_gender = card_gender

                # Layer 0: full card in white from screen_start (lead-in preview)
                # Layer 1: karaoke reveal starting at true_start — no offset from \h
                f.write(f"Dialogue: 0,{format_to_ass_time(card['screen_start'])},{format_to_ass_time(card['screen_end'])},{assigned_style},,0,0,0,,{future_override}{payload_bg.strip()}\n")
                f.write(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['screen_end'])},{assigned_style},,0,0,0,,{past_override}{payload_k.strip()}\n")

                # Interlude marker (if next card far away)
                if idx < len(cards) - 1:
                    next_card = cards[idx + 1]
                    musical_gap = next_card["true_start"] - card["true_end"]
                    if musical_gap >= (8.0 * beat_duration):
                        int_start = card["true_end"] + 0.5
                        int_end = next_card["screen_start"]
                        if int_end > int_start + 1.0:
                            f.write(f"Dialogue: 0,{format_to_ass_time(int_start)},{format_to_ass_time(int_end)},Title,,0,0,0,,[Interlude]\n")
        else:
            # alternate-rows: two-slot karaoke, always 2 cards visible.
            # Incoming card appears at the START of the adjacent card's singing (full lead-in)
            # with an INSTANT snap (no fade animation) so the other slot's karaoke is the only
            # animation on screen. Only the outgoing slot fades at the end of a card.
            for ci, card in enumerate(cards):
                slot = "Row_Top_Left" if ci % 2 == 0 else "Row_Bottom_Right"

                if card.get("style_tag") == "female":
                    past_primary = COLOR_RED
                elif card.get("style_tag") == "duet":
                    past_primary = COLOR_PINK
                else:
                    past_primary = COLOR_BLUE

                # Build karaoke payload
                payload_k = ""
                total_words = len(card["tokens"])
                for w_idx, token in enumerate(card["tokens"]):
                    word = token["text"].lstrip() if w_idx == 0 else token["text"]
                    if char_scroll:
                        dur = (token["end_time"] - token["start_time"]) or 0.01
                        ch_durs = [dur / len(word)] * len(word) if len(word) > 1 else [dur]
                        for ci2, ch in enumerate(word):
                            cs = max(1, int(round(ch_durs[ci2] * 100)))
                            payload_k += f"{{\\k{cs}}}{ch}"
                    else:
                        duration_cs = max(1, int(round((token["end_time"] - token["start_time"]) * 100)))
                        payload_k += f"{{\\k{duration_cs}}}{word}"
                    if w_idx < total_words - 1:
                        nxt = card["tokens"][w_idx + 1]
                        g = nxt["start_time"] - token["end_time"]
                        if g > 0.005:
                            gcs = int(round(g * 100))
                            if gcs > 0:
                                payload_k += f"{{\\k{gcs}}}"

                card_text = " ".join(t["text"].strip() for t in card["tokens"])

                if ci == 0:
                    # First card — fade in at song start
                    f.write(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{{\\fad(300,300)\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_WHITE}}}{payload_k}\n")

                else:
                    prev_card = cards[ci - 1]
                    gap_before = card["true_start"] - prev_card["true_end"]

                    if gap_before < bar_duration:
                        # Incoming: appears instantly (no fade) when the adjacent card starts singing.
                        # No animation = the only moving element is the karaoke in the other slot.
                        fut_ov = f"{{\\c{COLOR_WHITE}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"
                        inc_s = prev_card["true_start"]
                        inc_e = card["true_start"]
                        if inc_e > inc_s:
                            f.write(f"Dialogue: 0,{format_to_ass_time(inc_s)},{format_to_ass_time(inc_e)},{slot},,0,0,0,,{fut_ov}{card_text}\n")

                    # Active: no fade-in (was already visible as incoming); fade out at end
                    past_ov = f"{{\\fad(0,300)\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_WHITE}}}"
                    f.write(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{past_ov}{payload_k}\n")

                # Interlude marker
                if ci < len(cards) - 1:
                    next_card = cards[ci + 1]
                    musical_gap = next_card["true_start"] - card["true_end"]
                    if musical_gap >= (8.0 * beat_duration):
                        int_start = card["true_end"] + 0.5
                        int_end = next_card["true_start"] - bar_duration
                        if int_end > int_start + 1.0:
                            f.write(f"Dialogue: 0,{format_to_ass_time(int_start)},{format_to_ass_time(int_end)},Title,,0,0,0,,[Interlude]\n")
                slot = "Row_Top_Left" if ci % 2 == 0 else "Row_Bottom_Right"

                if card.get("style_tag") == "female":
                    past_primary = COLOR_RED
                elif card.get("style_tag") == "duet":
                    past_primary = COLOR_PINK
                else:
                    past_primary = COLOR_BLUE

                # Build karaoke payload
                payload_k = ""
                total_words = len(card["tokens"])
                for w_idx, token in enumerate(card["tokens"]):
                    word = token["text"].lstrip() if w_idx == 0 else token["text"]
                    if char_scroll:
                        dur = (token["end_time"] - token["start_time"]) or 0.01
                        ch_durs = [dur / len(word)] * len(word) if len(word) > 1 else [dur]
                        for ci2, ch in enumerate(word):
                            cs = max(1, int(round(ch_durs[ci2] * 100)))
                            payload_k += f"{{\\k{cs}}}{ch}"
                    else:
                        duration_cs = max(1, int(round((token["end_time"] - token["start_time"]) * 100)))
                        payload_k += f"{{\\k{duration_cs}}}{word}"
                    if w_idx < total_words - 1:
                        nxt = card["tokens"][w_idx + 1]
                        g = nxt["start_time"] - token["end_time"]
                        if g > 0.005:
                            gcs = int(round(g * 100))
                            if gcs > 0:
                                payload_k += f"{{\\k{gcs}}}"

                card_text = " ".join(t["text"].strip() for t in card["tokens"])
                fut_ov  = f"{{\\fad(250,0)\\c{COLOR_WHITE}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"
                past_ov = f"{{\\fad(0,300)\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_WHITE}}}"

                if ci == 0:
                    # Top slot first use: fade in+out
                    f.write(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{{\\fad(300,300)\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_WHITE}}}{payload_k}\n")

                elif ci == 1:
                    # Bottom slot first use — show incoming from song start (once, at song beginning)
                    if card["true_start"] - cards[0]["true_end"] < bar_duration:
                        inc_s, inc_e = cards[0]["true_start"], card["true_start"]
                        if inc_e > inc_s:
                            f.write(f"Dialogue: 0,{format_to_ass_time(inc_s)},{format_to_ass_time(inc_e)},{slot},,0,0,0,,{fut_ov}{card_text}\n")
                    f.write(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{past_ov}{payload_k}\n")

                else:
                    # ci >= 2: slot was last occupied by card ci-2.
                    # Incoming appears when ci-2 FINISHES → only this slot changes; other is stable.
                    prev_same = cards[ci - 2]
                    if card["true_start"] - prev_same["true_end"] < bar_duration:
                        inc_s = prev_same["true_end"]   # slot freed here
                        inc_e = card["true_start"]
                        if inc_e > inc_s:
                            f.write(f"Dialogue: 0,{format_to_ass_time(inc_s)},{format_to_ass_time(inc_e)},{slot},,0,0,0,,{fut_ov}{card_text}\n")
                    # Active: was already visible → no fade-in; fade out at end
                    f.write(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{past_ov}{payload_k}\n")

                # Interlude marker
                if ci < len(cards) - 1:
                    next_card = cards[ci + 1]
                    musical_gap = next_card["true_start"] - card["true_end"]
                    if musical_gap >= (8.0 * beat_duration):
                        int_start = card["true_end"] + 0.5
                        int_end = next_card["true_start"] - bar_duration
                        if int_end > int_start + 1.0:
                            f.write(f"Dialogue: 0,{format_to_ass_time(int_start)},{format_to_ass_time(int_end)},Title,,0,0,0,,[Interlude]\n")

        print(f"✅ Generated ASS file: {out_path}")

    # Write gender sections JSON for icon overlay
    sections = []
    for card in cards:
        g = (card.get("style_tag") or "male")
        if g == "default":
            g = "male"
        if sections and sections[-1]["gender"] == g:
            sections[-1]["end"] = card["true_end"]
        else:
            sections.append({"gender": g, "start": card["true_start"], "end": card["true_end"]})
    gender_json_path = os.path.splitext(out_path)[0] + ".gender_sections.json"
    with open(gender_json_path, "w", encoding="utf-8") as gf:
        json.dump(sections, gf, indent=2)
    print(f"📝 Wrote gender sections: {gender_json_path}")

    # update assets.json paths and copy ASS into inputs/Subtitles
    try:
        with open(ASSETS_PATH, "r", encoding="utf-8") as dbf:
            assets_data = json.load(dbf)
        project_root = os.path.dirname(ASSETS_PATH)
        inputs_sub_dir = os.path.join(project_root, "inputs", "Subtitles")
        os.makedirs(inputs_sub_dir, exist_ok=True)
        target_inputs_ass = os.path.join(inputs_sub_dir, os.path.basename(out_path))
        try:
            shutil.copyfile(out_path, target_inputs_ass)
            print(f"📝 Copied ASS into inputs/Subtitles: {target_inputs_ass}")
        except Exception as e:
            print(f"⚠️ Warning: Failed to copy ASS into inputs/Subtitles: {e}")
        rel_sub_path = os.path.relpath(target_inputs_ass, project_root)
        if "inputs" not in assets_data:
            assets_data["inputs"] = {}
        assets_data["inputs"]["subtitles_ass"] = rel_sub_path
        assets_data["inputs"]["subtitles_production_ass"] = rel_sub_path
        with open(ASSETS_PATH, "w", encoding="utf-8") as dbf:
            json.dump(assets_data, dbf, indent=4)
    except Exception as e:
        print(f"⚠️ Warning: Database auto-update failed: {e}")


def write_midi_report(midi_path, out_path, midi_file, tokens, tempo_events, preview_path=None, report_path=None):
    report_path = report_path or os.path.splitext(out_path)[0] + ".report.txt"
    report_dir = os.path.dirname(os.path.abspath(report_path))
    if report_dir:
        os.makedirs(report_dir, exist_ok=True)
    lines = []
    lines.append(f"MIDI report for: {midi_path}")
    lines.append(f"ASS output: {out_path}")
    lines.append("")
    time_sigs = parse_time_signatures(midi_file)
    lines.append(f"- time signatures found: {len(time_sigs)}")
    if preview_path:
        lines.append(f"- preview JSON: {preview_path}")
    with open(report_path, "w", encoding="utf-8") as rf:
        rf.write("\n".join(lines) + "\n")
    print(f"📝 Wrote MIDI report: {report_path}")


def write_preview_json(midi_path, out_path, tokens, preview_path, midi_file, tempo_events):
    cards = group_cards(tokens)
    preview_data = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "midi_path": midi_path,
        "ass_path": out_path,
        "target_bpm": TARGET_BPM,
        "tempo_events": [{"tick": t, "tempo": tempo, "bpm": mido.tempo2bpm(tempo)} for t, tempo in tempo_events],
        "tokens": [{"text": tok["text"].strip(), "start_time": tok["start_time"], "end_time": tok["end_time"], "card_break": tok["card_break"], "style_tag": tok.get("style_tag")} for tok in tokens],
        "cards": [{"index": i+1, "token_count": len(c["tokens"]), "style_tag": c.get("style_tag", "default"), "text": "".join([t["text"].strip() + " " for t in c["tokens"]]).strip(), "start_time": c["true_start"], "end_time": c["true_end"]} for i, c in enumerate(cards)],
    }
    with open(preview_path, "w", encoding="utf-8") as pf:
        json.dump(preview_data, pf, indent=2, ensure_ascii=False)
    print(f"📝 Wrote preview JSON: {preview_path}")


def parse_args():
    p = argparse.ArgumentParser(description="Convert MIDI lyrics to karaoke ASS with report + preview JSON.")
    p.add_argument("midi", nargs="?", help="Input MIDI file. If omitted, uses MIDI_FILE env.")
    p.add_argument("--out", "-o", help="Output ASS path. Default based on MIDI path or SUBTITLES_ASS env.")
    p.add_argument("--report", "-r", help="Report output path. Defaults to <ass output>.report.txt")
    p.add_argument("--preview", "-p", help="Preview JSON path. When set, preview JSON will be written.")
    p.add_argument("--styles", "-s", help="Sidecar styles file mapping card numbers to M/F (simple text file).")
    p.add_argument("--mode", choices=["preview", "final", "both"], default="both")
    p.add_argument("--target-bpm", type=float, help="Override target BPM used for card grouping and timing.")
    p.add_argument("--char-scroll", action="store_true", help="Scroll characters one-by-one instead of syllable tokens.")
    p.add_argument("--alternate-rows", action="store_true", help="Show current token on top and incoming token on bottom (two-slot mode).")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    midi_path = args.midi or os.environ.get("MIDI_FILE")
    if not midi_path:
        print("❌ ERROR: No MIDI input provided. Set MIDI_FILE env or pass MIDI path.")
        sys.exit(1)
    out_path = args.out or os.environ.get("SUBTITLES_ASS")
    if not out_path:
        out_path = os.path.join("inputs", "Subtitles", f"{os.path.splitext(os.path.basename(midi_path))[0]}.ass")

    preview_path = args.preview or os.path.splitext(out_path)[0] + ".preview.json"
    report_path = args.report or os.path.splitext(out_path)[0] + ".report.txt"

    if args.target_bpm:
        TARGET_BPM = args.target_bpm

    tokens = extract_syllables_from_midi(midi_path)
    mid = mido.MidiFile(midi_path)
    tempo_events = parse_tempo_events(mid)

    write_midi_report(midi_path, out_path, mid, tokens, tempo_events, preview_path=preview_path, report_path=report_path)

    default_styles_path = os.path.splitext(out_path)[0] + ".styles.txt"
    styles_path = None
    if getattr(args, 'styles', None):
        styles_path = args.styles
        print(f"🎨 Explicit styles sidecar provided: {styles_path}")
    elif os.path.isfile(default_styles_path):
        styles_path = default_styles_path
        print(f"🎨 Using existing styles sidecar: {styles_path}")
        print(f"🔁 Regenerating canonical ASS from MIDI + existing styles sidecar into: {out_path}")
    else:
        print(f"🎨 No styles sidecar found. Creating default styles sidecar: {default_styles_path}")
        try:
            cards_for_styles = group_cards(tokens)
            write_styles_sidecar(cards_for_styles, out_path, midi_path=midi_path)
            styles_path = default_styles_path
            print(f"🆕 Created base styles sidecar with {len(cards_for_styles)} cards from default gender {GENDER_SELECTION}.")
            print(f"✅ Initial base ASS will be generated at: {out_path}")
        except Exception:
            print(f"⚠️ Warning: Failed to create default styles sidecar: {default_styles_path}")

    styles_map = None
    if styles_path and os.path.isfile(styles_path):
        styles_map = parse_styles_file(styles_path)
    if args.mode in ("final", "both"):
        compile_ass_file(tokens, out_path, styles_map=styles_map, char_scroll=args.char_scroll, alternate_rows=args.alternate_rows)
        print(f"✅ Final ASS generated at {out_path}. Re-run option 5 after editing {styles_path} to update the ASS.")
    if args.mode in ("preview", "both"):
        write_preview_json(midi_path, out_path, tokens, preview_path, mid, tempo_events)
