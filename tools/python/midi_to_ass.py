#!/usr/bin/env python3
"""
Master Orchestrator Script for Karaoke Subtitle Pipeline.
Invokes modular libraries (parser, cards, compiler) with strict error checks.
"""

import os
import sys
import argparse
import json
import mido

CURRENT_DIR = os.path.abspath(os.path.dirname(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from karaoke.parser import extract_syllables_from_midi, parse_tempo_events
from karaoke.cards import group_cards, parse_styles_file, write_styles_sidecar
from karaoke.compiler import compile_ass_file, write_midi_report, write_preview_json

ASSETS_PATH = os.path.join(CURRENT_DIR, "..", "..", "assets.json")

def load_project_config():
    song_title = "Unknown Title"
    song_author = "Unknown Author"
    gender_selection = "Male"
    raw_bpm = "120.0"
    max_tokens = 10
    max_gap_seconds = 5.0

    if os.path.exists(ASSETS_PATH):
        try:
            with open(ASSETS_PATH, "r", encoding="utf-8") as fh:
                cfg = json.load(fh)
                inputs = cfg.get("inputs", {})
                settings = cfg.get("settings", {})
                song_title = inputs.get("song_title", song_title)
                song_author = inputs.get("song_author", song_author)
                gender_selection = inputs.get("vocalist_gender", gender_selection)
                raw_bpm = inputs.get("bpm", raw_bpm)
                max_tokens = int(inputs.get("max_tokens_per_card", max_tokens))
                max_gap_seconds = float(settings.get("max_gap_seconds", 5.0))
        except Exception as e:
            print(f"⚠️ Warning: Could not fully read assets.json: {e}", file=sys.stderr)
    
    try:
        target_bpm = float(raw_bpm)
    except Exception:
        target_bpm = 120.0

    return song_title, song_author, gender_selection, target_bpm, max_tokens, max_gap_seconds

def parse_args():
    p = argparse.ArgumentParser(description="Modular MIDI to Karaoke ASS Converter.")
    p.add_argument("midi", nargs="?", help="Input MIDI source file path.")
    p.add_argument("--out", "-o", help="Output ASS path.")
    p.add_argument("--report", "-r", help="Report output path.")
    p.add_argument("--preview", "-p", help="Preview JSON path.")
    p.add_argument("--styles", "-s", help="Sidecar styles file path.")
    p.add_argument("--mode", choices=["preview", "final", "both"], default="both")
    p.add_argument("--target-bpm", type=float, help="Override target BPM.")
    p.add_argument("--char-scroll", action="store_true", help="Scroll character-by-character.")
    p.add_argument("--alternate-rows", action="store_true", help="Use alternate dual-card rows layout.")
    return p.parse_args()

if __name__ == "__main__":
    args = parse_args()
    source_path = args.midi or os.environ.get("MIDI_FILE")
    
    if not source_path:
        print("❌ FATAL ERROR: No input MIDI provided. Set MIDI_FILE env or pass file path.", file=sys.stderr)
        sys.exit(1)

    song_title, song_author, gender_selection, target_bpm, max_tokens, max_gap_seconds = load_project_config()
    if args.target_bpm:
        target_bpm = args.target_bpm

    out_path = args.out or os.environ.get("SUBTITLES_ASS")
    if not out_path:
        out_path = os.path.join("inputs", "Subtitles", f"{os.path.splitext(os.path.basename(source_path))[0]}.ass")

    preview_path = args.preview or os.path.splitext(out_path)[0] + ".preview.json"
    report_path = args.report or os.path.splitext(out_path)[0] + ".report.txt"

    tokens, mid, tempo_events = extract_syllables_from_midi(source_path, target_bpm=target_bpm)
    write_midi_report(source_path, out_path, mid, tokens, tempo_events, preview_path=preview_path, report_path=report_path, source_type="midi")

    default_styles_path = os.path.splitext(out_path)[0] + ".styles.txt"
    styles_path = None
    if getattr(args, 'styles', None):
        styles_path = args.styles
    elif os.path.isfile(default_styles_path):
        styles_path = default_styles_path
    else:
        try:
            cards_for_styles = group_cards(tokens, max_tokens=max_tokens)
            write_styles_sidecar(cards_for_styles, out_path, gender_selection=gender_selection, assets_path=ASSETS_PATH)
            styles_path = default_styles_path
        except Exception as e:
            print(f"⚠️ Warning: Failed to create default styles sidecar: {e}", file=sys.stderr)

    styles_map = parse_styles_file(styles_path) if styles_path else {}
    cards_list = group_cards(tokens, max_tokens=max_tokens)

    if args.mode in ("final", "both"):
        compile_ass_file(
            tokens, out_path, cards_list, 
            styles_map=styles_map, 
            char_scroll=args.char_scroll, 
            alternate_rows=args.alternate_rows, 
            target_bpm=target_bpm, 
            song_title=song_title, 
            song_author=song_author, 
            max_tokens_per_card=max_tokens, 
            max_gap_seconds=max_gap_seconds,
            assets_path=ASSETS_PATH
        )

    if args.mode in ("preview", "both"):
        write_preview_json(source_path, out_path, tokens, preview_path, tempo_events, target_bpm=target_bpm, source_type="midi")