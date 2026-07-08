#!/usr/bin/env python3
"""Convert a lyric-bearing MIDI file into a MuseScore-friendly MusicXML score.

This exporter is intentionally simple and focuses on one melodic line with lyrics,
so the generated file is easy to edit in MuseScore for engraving workflows.
"""

from __future__ import annotations

import argparse
import os
import unicodedata
import xml.etree.ElementTree as ET
from dataclasses import dataclass

import mido


MAJOR_KEY_TO_FIFTHS = {
    "Cb": -7,
    "Gb": -6,
    "Db": -5,
    "Ab": -4,
    "Eb": -3,
    "Bb": -2,
    "F": -1,
    "C": 0,
    "G": 1,
    "D": 2,
    "A": 3,
    "E": 4,
    "B": 5,
    "F#": 6,
    "C#": 7,
}

MINOR_KEY_TO_FIFTHS = {
    "Ab": -7,
    "Eb": -6,
    "Bb": -5,
    "F": -4,
    "C": -3,
    "G": -2,
    "D": -1,
    "A": 0,
    "E": 1,
    "B": 2,
    "F#": 3,
    "C#": 4,
    "G#": 5,
    "D#": 6,
    "A#": 7,
}


@dataclass
class NoteEvent:
    start_tick: int
    end_tick: int
    note: int
    lyric: str | None = None


def _xml_indent(elem: ET.Element, level: int = 0) -> None:
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        for child in elem:
            _xml_indent(child, level + 1)
        if not elem[-1].tail or not elem[-1].tail.strip():
            elem[-1].tail = i
    elif level and (not elem.tail or not elem.tail.strip()):
        elem.tail = i


def _note_to_pitch(note_num: int) -> tuple[str, int, int]:
    names = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    alters = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]
    pc = note_num % 12
    step = names[pc]
    alter = alters[pc]
    octave = (note_num // 12) - 1
    return step, alter, octave


def _parse_key_signature(raw_key: str | None) -> tuple[int, str]:
    """Convert mixed key formats to MusicXML fifths/mode.

    Accepts values like: "G", "Em", "G-Minor", "Bb Major", "F#m".
    """
    if not raw_key:
        return 0, "major"

    key = raw_key.strip().replace("♯", "#").replace("♭", "b")
    if not key:
        return 0, "major"

    tonic = key
    mode = "major"

    if "-" in key:
        left, right = key.split("-", 1)
        tonic = left.strip()
        low = right.strip().lower()
        mode = "minor" if low.startswith("min") else "major"
    elif " " in key:
        parts = key.split()
        tonic = parts[0].strip()
        low = parts[-1].strip().lower()
        mode = "minor" if low.startswith("min") else "major"
    elif key.lower().endswith("m") and len(key) > 1:
        tonic = key[:-1]
        mode = "minor"

    tonic = tonic[:1].upper() + tonic[1:]
    mapping = MINOR_KEY_TO_FIFTHS if mode == "minor" else MAJOR_KEY_TO_FIFTHS
    return mapping.get(tonic, 0), mode


def _extract_notes_and_lyrics(midi_path: str) -> tuple[list[NoteEvent], int, int, str | None, tuple[int, int]]:
    mid = mido.MidiFile(midi_path)
    tr = mid.tracks[0]

    # Pull score-level metadata from all tracks because DAWs often write
    # key/time/tempo meta events outside the melody track.
    first_tempo = None
    first_tempo_tick = None
    first_key_signature = None
    first_key_tick = None
    first_time_signature = (4, 4)
    first_time_tick = None

    for meta_tr in mid.tracks:
        meta_tick = 0
        for msg in meta_tr:
            meta_tick += msg.time
            if msg.type == "set_tempo":
                if first_tempo_tick is None or meta_tick < first_tempo_tick:
                    first_tempo_tick = meta_tick
                    first_tempo = msg.tempo
            elif msg.type == "key_signature":
                if first_key_tick is None or meta_tick < first_key_tick:
                    first_key_tick = meta_tick
                    first_key_signature = msg.key
            elif msg.type == "time_signature":
                if first_time_tick is None or meta_tick < first_time_tick:
                    first_time_tick = meta_tick
                    first_time_signature = (int(msg.numerator), int(msg.denominator))

    abs_tick = 0
    active: dict[tuple[int, int], list[int]] = {}
    notes: list[tuple[int, int, int]] = []
    lyrics: list[tuple[int, str]] = []

    for msg in tr:
        abs_tick += msg.time
        if msg.type == "lyrics":
            txt = unicodedata.normalize("NFC", str(msg.text or ""))
            lyrics.append((abs_tick, txt))
        elif msg.type == "note_on" and msg.velocity > 0:
            active.setdefault((msg.channel, msg.note), []).append(abs_tick)
        elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
            key = (msg.channel, msg.note)
            if key in active and active[key]:
                start = active[key].pop(0)
                end = max(start + 1, abs_tick)
                notes.append((start, end, msg.note))

    notes.sort(key=lambda x: (x[0], x[2]))

    # Attach each lyric to the next note onset. This mirrors the strict MuseScore workaround.
    out: list[NoteEvent] = [NoteEvent(s, e, n, None) for s, e, n in notes]
    note_idx = 0
    for ltick, ltxt in lyrics:
        while note_idx < len(out) and out[note_idx].start_tick < ltick:
            note_idx += 1
        if note_idx < len(out):
            out[note_idx].lyric = ltxt
            note_idx += 1

    if first_tempo is None:
        first_tempo = mido.bpm2tempo(120)

    bpm = max(1, int(round(mido.tempo2bpm(first_tempo))))
    return out, mid.ticks_per_beat, bpm, first_key_signature, first_time_signature


def _append_pitch(note_elem: ET.Element, midi_note: int) -> None:
    step, alter, octave = _note_to_pitch(midi_note)
    pitch = ET.SubElement(note_elem, "pitch")
    ET.SubElement(pitch, "step").text = step
    if alter:
        ET.SubElement(pitch, "alter").text = str(alter)
    ET.SubElement(pitch, "octave").text = str(octave)


def _duration_type_and_dots(duration_ticks: int, divisions: int) -> tuple[str | None, int]:
    """Best-effort MusicXML type/dot mapping from tick duration.

    Uses quarter-note-based divisions and tolerates slight tick jitter from DAW export.
    """
    if duration_ticks <= 0 or divisions <= 0:
        return None, 0

    quarter_len = duration_ticks / float(divisions)
    base_lengths = [
        ("whole", 4.0),
        ("half", 2.0),
        ("quarter", 1.0),
        ("eighth", 0.5),
        ("16th", 0.25),
        ("32nd", 0.125),
        ("64th", 0.0625),
    ]

    best_type = None
    best_dots = 0
    best_err = float("inf")

    for note_type, base in base_lengths:
        for dots in (0, 1, 2):
            multiplier = 2.0 - (0.5 ** dots)
            cand = base * multiplier
            err = abs(quarter_len - cand)
            if err < best_err:
                best_err = err
                best_type = note_type
                best_dots = dots

    # Accept only reasonably close matches; otherwise rely on duration alone.
    if best_type is None:
        return None, 0
    relative_err = best_err / max(quarter_len, 1e-9)
    if relative_err > 0.25:
        return None, 0
    return best_type, best_dots


def midi_to_musicxml(midi_path: str, xml_path: str, title: str | None = None, key_hint: str | None = None) -> None:
    notes, divisions, bpm, midi_key, midi_time = _extract_notes_and_lyrics(midi_path)

    score = ET.Element("score-partwise", version="3.1")
    work = ET.SubElement(score, "work")
    ET.SubElement(work, "work-title").text = title or os.path.splitext(os.path.basename(midi_path))[0]

    part_list = ET.SubElement(score, "part-list")
    score_part = ET.SubElement(part_list, "score-part", id="P1")
    ET.SubElement(score_part, "part-name").text = "Voice"

    part = ET.SubElement(score, "part", id="P1")

    beats, beat_type = midi_time
    measure_len = int(round(divisions * beats * (4.0 / max(1, beat_type))))
    if measure_len <= 0:
        measure_len = divisions * 4

    current_tick = 0
    measure_no = 1
    measure = ET.SubElement(part, "measure", number=str(measure_no))

    attributes = ET.SubElement(measure, "attributes")
    ET.SubElement(attributes, "divisions").text = str(divisions)
    fifths, mode = _parse_key_signature(key_hint or midi_key)
    key = ET.SubElement(attributes, "key")
    ET.SubElement(key, "fifths").text = str(fifths)
    ET.SubElement(key, "mode").text = mode
    time = ET.SubElement(attributes, "time")
    ET.SubElement(time, "beats").text = str(beats)
    ET.SubElement(time, "beat-type").text = str(beat_type)
    clef = ET.SubElement(attributes, "clef")
    ET.SubElement(clef, "sign").text = "G"
    ET.SubElement(clef, "line").text = "2"

    direction = ET.SubElement(measure, "direction", placement="above")
    direction_type = ET.SubElement(direction, "direction-type")
    metronome = ET.SubElement(direction_type, "metronome")
    ET.SubElement(metronome, "beat-unit").text = "quarter"
    ET.SubElement(metronome, "per-minute").text = str(bpm)
    ET.SubElement(direction, "sound", tempo=str(bpm))

    def next_measure() -> ET.Element:
        nonlocal measure_no
        measure_no += 1
        return ET.SubElement(part, "measure", number=str(measure_no))

    for ev in notes:
        # Fill gap with rests when needed.
        while current_tick < ev.start_tick:
            used_in_measure = current_tick % measure_len
            remaining_measure = measure_len - used_in_measure
            rest_ticks = min(remaining_measure, ev.start_tick - current_tick)
            if rest_ticks <= 0:
                break
            if used_in_measure == 0 and current_tick > 0:
                measure = next_measure()

            rest = ET.SubElement(measure, "note")
            ET.SubElement(rest, "rest")
            ET.SubElement(rest, "duration").text = str(rest_ticks)
            ET.SubElement(rest, "voice").text = "1"
            rest_type, rest_dots = _duration_type_and_dots(rest_ticks, divisions)
            if rest_type is not None:
                ET.SubElement(rest, "type").text = rest_type
                for _ in range(rest_dots):
                    ET.SubElement(rest, "dot")
            current_tick += rest_ticks

        if current_tick % measure_len == 0 and current_tick > 0:
            measure = next_measure()

        dur_ticks = max(1, ev.end_tick - ev.start_tick)
        note = ET.SubElement(measure, "note")
        _append_pitch(note, ev.note)
        ET.SubElement(note, "duration").text = str(dur_ticks)
        ET.SubElement(note, "voice").text = "1"
        note_type, note_dots = _duration_type_and_dots(dur_ticks, divisions)
        if note_type is not None:
            ET.SubElement(note, "type").text = note_type
            for _ in range(note_dots):
                ET.SubElement(note, "dot")

        if ev.lyric is not None:
            lyr = ET.SubElement(note, "lyric", number="1")
            ET.SubElement(lyr, "syllabic").text = "single"
            ET.SubElement(lyr, "text").text = ev.lyric

        current_tick = ev.end_tick

    _xml_indent(score)
    ET.ElementTree(score).write(xml_path, encoding="utf-8", xml_declaration=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert Logic-style lyric MIDI into editable MusicXML.")
    parser.add_argument("input_midi", help="Input MIDI file")
    parser.add_argument("-o", "--output", help="Output .musicxml path")
    parser.add_argument("--title", help="Score title")
    parser.add_argument("--key", help="Optional key hint, e.g. G-Minor, Bb Major, Em")
    args = parser.parse_args()

    if not os.path.exists(args.input_midi):
        print(f"ERROR: Missing input MIDI: {args.input_midi}")
        return 1

    out = args.output or os.path.splitext(args.input_midi)[0] + ".musicxml"
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)

    midi_to_musicxml(args.input_midi, out, title=args.title, key_hint=args.key)
    print(f"Wrote MusicXML: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
