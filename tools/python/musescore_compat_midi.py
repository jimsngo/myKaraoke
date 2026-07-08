#!/usr/bin/env python3
"""Create a MuseScore-friendly MIDI copy from Logic-generated files.

This tool focuses on import stability for engraving workflows:
- Convert meta text events to lyric events (optional).
- Normalize lyric text to NFC and trim empty lyric tokens.
- Reorder same-tick events so lyric events occur before note_on.
- Optionally flatten dense tempo maps to a single tempo event at tick 0.
"""

from __future__ import annotations

import argparse
import unicodedata
from pathlib import Path

import mido


def _event_priority(msg: mido.Message | mido.MetaMessage) -> int:
    """Stable order for events sharing the same absolute tick."""
    if msg.is_meta and msg.type in ("track_name", "instrument_name", "marker", "cue_marker"):
        return 0
    if msg.is_meta and msg.type in ("time_signature", "key_signature", "set_tempo"):
        return 1
    if msg.is_meta and msg.type == "lyrics":
        return 2
    if msg.type == "note_off" or (msg.type == "note_on" and getattr(msg, "velocity", 0) == 0):
        return 3
    if msg.type == "note_on" and getattr(msg, "velocity", 0) > 0:
        return 4
    return 5


def normalize_midi_for_musescore(
    src_path: Path,
    dst_path: Path,
    *,
    flatten_tempo: bool,
    keep_text_events: bool,
    drop_empty_lyrics: bool,
    align_lyrics_to_note_on: bool,
) -> dict:
    src = mido.MidiFile(src_path)
    out = mido.MidiFile(type=src.type, ticks_per_beat=src.ticks_per_beat)

    # Capture earliest global score metadata for robust import defaults.
    first_tempo = None
    first_key_sig = None
    first_key_tick = None
    first_time_sig = None
    first_time_tick = None
    for tr in src.tracks:
        abs_tick = 0
        for msg in tr:
            abs_tick += msg.time
            if msg.type == "set_tempo":
                first_tempo = msg.tempo
            elif msg.type == "key_signature":
                if first_key_tick is None or abs_tick < first_key_tick:
                    first_key_tick = abs_tick
                    first_key_sig = msg.key
            elif msg.type == "time_signature":
                if first_time_tick is None or abs_tick < first_time_tick:
                    first_time_tick = abs_tick
                    first_time_sig = (
                        int(msg.numerator),
                        int(msg.denominator),
                        int(msg.clocks_per_click),
                        int(msg.notated_32nd_notes_per_beat),
                    )
    if first_tempo is None:
        first_tempo = mido.bpm2tempo(120)

    stats = {
        "lyrics_in": 0,
        "text_in": 0,
        "lyrics_out": 0,
        "text_to_lyrics": 0,
        "tempo_in": 0,
        "tempo_out": 0,
        "dropped_empty": 0,
    }

    for track_idx, tr in enumerate(src.tracks):
        events: list[tuple[int, int, mido.Message | mido.MetaMessage]] = []
        abs_tick = 0

        for seq, msg in enumerate(tr):
            abs_tick += msg.time

            if msg.type == "set_tempo":
                stats["tempo_in"] += 1
                if flatten_tempo:
                    continue

            if msg.type == "lyrics":
                stats["lyrics_in"] += 1
                txt = unicodedata.normalize("NFC", str(msg.text))
                if drop_empty_lyrics and txt.strip() == "":
                    stats["dropped_empty"] += 1
                    continue
                msg = mido.MetaMessage("lyrics", text=txt, time=0)
                stats["lyrics_out"] += 1
            elif msg.type == "text" and not keep_text_events:
                stats["text_in"] += 1
                txt = unicodedata.normalize("NFC", str(msg.text))
                if drop_empty_lyrics and txt.strip() == "":
                    stats["dropped_empty"] += 1
                    continue
                msg = mido.MetaMessage("lyrics", text=txt, time=0)
                stats["text_to_lyrics"] += 1
                stats["lyrics_out"] += 1
            elif msg.type == "text":
                stats["text_in"] += 1

            events.append((abs_tick, seq, msg))

        if flatten_tempo and track_idx == 0:
            events.append((0, -1, mido.MetaMessage("set_tempo", tempo=first_tempo, time=0)))

        if track_idx == 0 and first_key_sig is not None:
            has_key_at_zero = any(tick == 0 and msg.type == "key_signature" for tick, _, msg in events)
            if not has_key_at_zero:
                events.append((0, -3, mido.MetaMessage("key_signature", key=first_key_sig, time=0)))

        if track_idx == 0 and first_time_sig is not None:
            has_time_at_zero = any(tick == 0 and msg.type == "time_signature" for tick, _, msg in events)
            if not has_time_at_zero:
                num, den, cpc, n32 = first_time_sig
                events.append(
                    (
                        0,
                        -2,
                        mido.MetaMessage(
                            "time_signature",
                            numerator=num,
                            denominator=den,
                            clocks_per_click=cpc,
                            notated_32nd_notes_per_beat=n32,
                            time=0,
                        ),
                    )
                )

        if align_lyrics_to_note_on:
            note_on_ticks = [
                tick
                for tick, _, msg in events
                if msg.type == "note_on" and getattr(msg, "velocity", 0) > 0
            ]
            if note_on_ticks:
                next_note_idx = 0
                aligned_events: list[tuple[int, int, mido.Message | mido.MetaMessage]] = []
                for tick, seq, msg in events:
                    if msg.is_meta and msg.type == "lyrics":
                        while next_note_idx < len(note_on_ticks) and note_on_ticks[next_note_idx] < tick:
                            next_note_idx += 1
                        if next_note_idx < len(note_on_ticks):
                            tick = note_on_ticks[next_note_idx]
                            next_note_idx += 1
                    aligned_events.append((tick, seq, msg))
                events = aligned_events

        # Reorder by absolute tick and semantic priority while preserving stability.
        events.sort(key=lambda item: (item[0], _event_priority(item[2]), item[1]))

        out_track = mido.MidiTrack()
        prev_tick = 0
        for tick, _, msg in events:
            delta = tick - prev_tick
            prev_tick = tick
            copied = msg.copy(time=delta)
            out_track.append(copied)
            if copied.type == "set_tempo":
                stats["tempo_out"] += 1

        out.tracks.append(out_track)

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst_path)
    return stats


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a MuseScore-friendly MIDI copy.")
    parser.add_argument("input_midi", help="Path to source MIDI")
    parser.add_argument("-o", "--output", help="Output MIDI path")
    parser.add_argument(
        "--keep-text-events",
        action="store_true",
        help="Keep text meta events instead of converting them to lyric events.",
    )
    parser.add_argument(
        "--keep-empty-lyrics",
        action="store_true",
        help="Keep blank lyric tokens (default drops blank/whitespace lyrics).",
    )
    parser.add_argument(
        "--no-flatten-tempo",
        action="store_true",
        help="Preserve all original tempo events (default flattens to one tempo at tick 0).",
    )
    parser.add_argument(
        "--no-align-lyrics",
        action="store_true",
        help="Preserve original lyric timing (default aligns each lyric to the next note_on tick).",
    )

    args = parser.parse_args()
    src = Path(args.input_midi)
    if not src.exists():
        print(f"ERROR: Input MIDI not found: {src}")
        return 1

    if args.output:
        dst = Path(args.output)
    else:
        dst = src.with_name(f"{src.stem}.musescore_compat.mid")

    stats = normalize_midi_for_musescore(
        src,
        dst,
        flatten_tempo=not args.no_flatten_tempo,
        keep_text_events=args.keep_text_events,
        drop_empty_lyrics=not args.keep_empty_lyrics,
        align_lyrics_to_note_on=not args.no_align_lyrics,
    )

    print(f"Wrote: {dst}")
    print(
        "Stats: "
        f"lyrics_in={stats['lyrics_in']} text_in={stats['text_in']} "
        f"text_to_lyrics={stats['text_to_lyrics']} lyrics_out={stats['lyrics_out']} "
        f"tempo_in={stats['tempo_in']} tempo_out={stats['tempo_out']} "
        f"dropped_empty={stats['dropped_empty']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
