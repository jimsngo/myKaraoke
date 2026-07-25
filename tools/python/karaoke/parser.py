#!/usr/bin/env python3
"""
Parser Module for Karaoke Pipeline.
Handles robust ingestion and time-mapping for MIDI and MusicXML sources.
Includes strict path validation and fail-safe exit guards.
"""

import os
import re
import sys
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
import mido

# Style tag regex matching
STYLE_TAG_RE = re.compile(r"^(?:#|@|\[)?\s*(?P<tag>female|male|duet|f|m|d)(?:(?:\]|:)\s*|\s+)(?P<text>.*)$", re.I)

def parse_style_tag(raw_text):
    m = STYLE_TAG_RE.match(raw_text.strip())
    if not m:
        return None, raw_text
    tag = m.group("tag").lower()
    text = m.group("text").strip()
    if tag in ("f", "female"):
        return "female", text
    if tag in ("d", "duet"):
        return "duet", text
    if tag in ("m", "male"):
        return "male", text
    return None, raw_text

def parse_tempo_events(mid: mido.MidiFile, target_bpm: float = 120.0):
    events = []
    try:
        for track in mid.tracks:
            abs_tick = 0
            for msg in track:
                abs_tick += msg.time
                if msg.type == "set_tempo":
                    events.append((abs_tick, msg.tempo))
    except Exception as e:
        print(f"❌ CRITICAL PARSER ERROR: Failed to read MIDI tracks for tempo: {e}", file=sys.stderr)
        sys.exit(1)
        
    events.sort(key=lambda x: x[0])
    
    if not events:
        events = [(0, int(60000000 / target_bpm))]
    else:
        if events[0][0] > 0:
            events.insert(0, (0, events[0][1]))
            
    dedup_events = []
    for tick, tempo in events:
        if dedup_events and dedup_events[-1][0] == tick:
            dedup_events[-1] = (tick, tempo)
        else:
            dedup_events.append((tick, tempo))
            
    return dedup_events

def parse_time_signatures(mid: mido.MidiFile):
    time_sigs = []
    try:
        for track in mid.tracks:
            abs_tick = 0
            for msg in track:
                abs_tick += msg.time
                if msg.type == "time_signature":
                    time_sigs.append((abs_tick, msg.numerator, msg.denominator))
    except Exception as e:
        print(f"❌ CRITICAL PARSER ERROR: Failed to parse time signatures: {e}", file=sys.stderr)
        sys.exit(1)
        
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
    
    sorted_events = sorted(tempo_events, key=lambda x: x[0])
    cur_tempo = sorted_events[0][1] if sorted_events else 500000
    
    for ev_tick, tempo in sorted_events:
        if ev_tick >= target_tick:
            break
        if ev_tick > cur_tick:
            total += (ev_tick - cur_tick) * cur_tempo / ticks_per_beat / 1_000_000.0
            cur_tick = ev_tick
        cur_tempo = tempo
        
    if target_tick > cur_tick:
        total += (target_tick - cur_tick) * cur_tempo / ticks_per_beat / 1_000_000.0
        
    return total

def seconds_from_quarters(target_quarter, tempo_events):
    if target_quarter <= 0:
        return 0.0
    total = 0.0
    cur_q = 0.0
    cur_bpm = tempo_events[0][1] if tempo_events else 120.0
    for ev_q, bpm in tempo_events:
        if ev_q > cur_q and ev_q <= target_quarter:
            total += (ev_q - cur_q) * (60.0 / cur_bpm)
            cur_q = ev_q
        cur_bpm = bpm
    if target_quarter > cur_q:
        total += (target_quarter - cur_q) * (60.0 / cur_bpm)
    return total

def _local_name(tag):
    return tag.split("}", 1)[-1] if "}" in tag else tag

def _load_musicxml_root(path):
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext != ".mxl":
            return ET.parse(path).getroot()

        with zipfile.ZipFile(path, "r") as zf:
            rootfile_path = None
            if "META-INF/container.xml" in zf.namelist():
                container = ET.fromstring(zf.read("META-INF/container.xml"))
                for elem in container.iter():
                    if _local_name(elem.tag) == "rootfile":
                        rootfile_path = elem.attrib.get("full-path")
                        if rootfile_path:
                            break
            if not rootfile_path:
                for name in zf.namelist():
                    if name.lower().endswith(".xml") and not name.startswith("META-INF/"):
                        rootfile_path = name
                        break
            if not rootfile_path:
                raise ValueError(f"Unable to find score XML inside {path}")
            return ET.fromstring(zf.read(rootfile_path))
    except Exception as e:
        print(f"❌ FATAL ERROR: Failed to load MusicXML structure from '{path}': {e}", file=sys.stderr)
        sys.exit(1)

def extract_syllables_from_midi(midi_path, target_bpm=120.0):
    # --- STRICT PATH GUARD ---
    if not midi_path or not os.path.exists(midi_path):
        print(f"❌ FATAL ERROR: MIDI file path does not exist: '{midi_path}'", file=sys.stderr)
        sys.exit(1)

    try:
        mid = mido.MidiFile(midi_path)
    except Exception as e:
        print(f"❌ FATAL ERROR: Failed to parse MIDI file (corrupted or invalid format): {e}", file=sys.stderr)
        sys.exit(1)

    ticks_per_beat = mid.ticks_per_beat
    tempo_events = parse_tempo_events(mid, target_bpm=target_bpm)

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
                    if pending_lyrics:
                        lyric = pending_lyrics.pop(0)
                        tokens.append({
                            "text": lyric["text"],
                            "raw_start_tick": lyric["tick"],
                            "raw_end_tick": abs_tick,
                            "start_time": ticks_to_seconds(lyric["tick"]),
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
                            "raw_start_tick": lyric["tick"],
                            "raw_end_tick": abs_tick,
                            "start_time": ticks_to_seconds(lyric["tick"]),
                            "end_time": ticks_to_seconds(abs_tick),
                            "card_break": lyric["card_break"],
                            "style_tag": lyric.get("style_tag"),
                        })
                else:
                    if pending_lyrics:
                        lyric = pending_lyrics.pop(0)
                        tokens.append({
                            "text": lyric["text"],
                            "raw_start_tick": lyric["tick"],
                            "raw_end_tick": abs_tick,
                            "start_time": ticks_to_seconds(lyric["tick"]),
                            "end_time": ticks_to_seconds(abs_tick),
                            "card_break": lyric["card_break"],
                            "style_tag": lyric.get("style_tag"),
                        })
                        
    tokens.sort(key=lambda t: t["start_time"])
    return tokens, mid, tempo_events