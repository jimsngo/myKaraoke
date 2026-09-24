#!/usr/bin/env python3
"""
Compiler Module for Karaoke Pipeline.
Handles ASS subtitle format generation, reports, and preview JSON creation.
Enforces fixed-time gap thresholds and [Instruments] interlude cards.
"""

import os
import sys
import json
import shutil
import mido
from datetime import datetime, timezone

COLOR_WHITE = "&H00FFFFFF&"
COLOR_BLACK = "&H00000000&"
COLOR_BLUE = "&H00DE7B1A&"  # male primary
COLOR_PINK = "&H00B469FF&"  # duet/female accent
COLOR_RED = "&H000000FF&"   # female (past) red
INTRO_DURATION = 5000

def format_to_ass_time(sec):
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = sec % 60
    return f"0{h}:{m:02d}:{s:05.2f}"

def compile_ass_file(raw_tokens, out_path, cards_list, styles_map=None, char_scroll=False, alternate_rows=False, target_bpm=120.0, song_title="Unknown Title", song_author="Unknown Author", max_tokens_per_card=10, max_gap_seconds=5.0, assets_path=None):
    cards = cards_list
    
    for i, card in enumerate(cards, start=1):
        if len(card["tokens"]) > max_tokens_per_card:
            card_text = "".join([t["text"] for t in card["tokens"]]).strip()
            print(f"⚠️ WARNING: Card {i} has {len(card['tokens'])} tokens (Limit: {max_tokens_per_card}).")
            
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

    from karaoke.cards import estimate_card_font_size
    for card in cards:
        card_text = "".join([t["text"].strip() + " " for t in card["tokens"]]).strip()
        font_size, est_width = estimate_card_font_size(card_text)
        card["font_size"] = font_size
        card["estimated_width"] = est_width

    content_lines = []
    content_lines.append("[Script Info]\nScriptType: v4.00+\nPlayResX: 1280\nPlayResY: 720\n\n")
    content_lines.append("[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n")
    FONT = "Arial"
    content_lines.append(f"Style: Title,{FONT},72,{COLOR_BLUE},{COLOR_BLUE},{COLOR_BLACK},{COLOR_BLACK},0,0,0,0,100,100,0,0,1,2,1,5,10,10,10,1\n")
    content_lines.append(f"Style: Row_Top_Center,{FONT},52,{COLOR_WHITE},{COLOR_WHITE},{COLOR_BLACK},{COLOR_BLACK},0,0,0,0,100,100,0,0,1,2,1,2,80,80,135,1\n")
    content_lines.append(f"Style: Row_Bottom_Center,{FONT},52,{COLOR_WHITE},{COLOR_WHITE},{COLOR_BLACK},{COLOR_BLACK},0,0,0,0,100,100,0,0,1,2,1,2,80,80,65,1\n\n")
    content_lines.append("[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")

    intro_end = INTRO_DURATION / 1000.0
    final_title_size = 80
    final_author_size = 50
    content_lines.append(f"Dialogue: 0,0:00:00.00,{format_to_ass_time(intro_end)},Title,,0,0,0,,{{\\fs{final_title_size}}}{song_title}\\N{{\\fs{final_author_size}}}{song_author}\n")

    if not alternate_rows:
        current_row = "top"
        for idx, card in enumerate(cards):
            payload_k = ""
            payload_bg = ""
            if card.get("font_size", 52) != 52:
                payload_k += f"{{\\fs{card['font_size']}}}"
                payload_bg += f"{{\\fs{card['font_size']}}}"

            current_cs = 0
            for w_idx, token in enumerate(card["tokens"]):
                if w_idx == 0:
                    payload_bg += token["text"].lstrip() if token["text"].startswith(" ") else token["text"]
                else:
                    payload_bg += token["text"]

                word = token["text"].lstrip() if w_idx == 0 else token["text"]
                tok_start_cs = max(0, int(round((token["start_time"] - card["true_start"]) * 100)))
                if tok_start_cs > current_cs:
                    payload_k += f"{{\\k{tok_start_cs - current_cs}}}"
                    current_cs = tok_start_cs
                    
                tok_end_cs = max(current_cs + 1, int(round((token["end_time"] - card["true_start"]) * 100)))
                dur_cs = tok_end_cs - current_cs
                payload_k += f"{{\\k{dur_cs}}}{word}"
                current_cs = tok_end_cs

            assigned_style = "Row_Top_Center" if current_row == "top" else "Row_Bottom_Center"
            current_row = "bottom" if current_row == "top" else "top"

            card_gender = card.get("style_tag") or "default"
            past_primary = COLOR_RED if card_gender == "female" else (COLOR_PINK if card_gender == "duet" else COLOR_BLUE)

            past_override = f"{{\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"
            future_override = f"{{\\c{COLOR_WHITE}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"

            screen_start = max(0.0, card["true_start"] - 2.0)
            if idx > 0:
                screen_start = max(screen_start, cards[idx-1]["true_end"])

            if card["true_start"] > screen_start:
                content_lines.append(f"Dialogue: 0,{format_to_ass_time(screen_start)},{format_to_ass_time(card['true_start'])},{assigned_style},,0,0,0,,{future_override}{payload_bg.strip()}\n")
            
            content_lines.append(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{assigned_style},,0,0,0,,{past_override}{payload_k.strip()}\n")
    else:
        # alternate-rows: two-slot karaoke with fixed-time gap threshold & [Instruments] cards
        for ci, card in enumerate(cards):
            slot = "Row_Top_Center" if ci % 2 == 0 else "Row_Bottom_Center"
            card_gender = card.get("style_tag") or "default"
            past_primary = COLOR_RED if card_gender == "female" else (COLOR_PINK if card_gender == "duet" else COLOR_BLUE)

            # Set the dynamic tag: \kf for smooth character scroll, \k for jump highlight
            active_k_tag = "\\kf" if char_scroll else "\\k"

            payload_k = ""
            current_cs = 0
            for w_idx, token in enumerate(card["tokens"]):
                word = token["text"].lstrip() if w_idx == 0 else token["text"]
                tok_start_cs = max(0, int(round((token["start_time"] - card["true_start"]) * 100)))
                
                # Process the time gaps (lead-in countdowns vs. pauses between words)
                if tok_start_cs > current_cs:
                    gap_dur = tok_start_cs - current_cs
                    
                    if w_idx == 0 and gap_dur > 0:
                        # ⏱️ Visual Countdown: Inject a vertical bar before the first word
                        payload_k += f"{{{active_k_tag}{gap_dur}}}| "
                    else:
                        # Silent gaps between normal words remain completely invisible
                        payload_k += f"{{\\k{gap_dur}}}"
                        
                    current_cs = tok_start_cs
                    
                tok_end_cs = max(current_cs + 1, int(round((token["end_time"] - card["true_start"]) * 100)))
                dur_cs = tok_end_cs - current_cs
                
                # Apply the dynamic tag to the actual singing word
                payload_k += f"{{{active_k_tag}{dur_cs}}}{word}"
                current_cs = tok_end_cs

            card_text = " ".join(t["text"].strip() for t in card["tokens"])
            fut_ov = f"{{\\c{COLOR_WHITE}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"
            past_ov = f"{{\\c{past_primary}\\2c{COLOR_WHITE}\\3c{COLOR_BLACK}}}"

            inc_e = card["true_start"]
            
            if ci == 0:
                inc_s = max(0.0, card["true_start"] - 2.0)
                if inc_e > inc_s:
                    content_lines.append(f"Dialogue: 0,{format_to_ass_time(inc_s)},{format_to_ass_time(inc_e)},{slot},,0,0,0,,{fut_ov}{card_text}\n")
                content_lines.append(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{past_ov}{payload_k}\n")
            else:
                prev_card = cards[ci - 1]
                gap_before = card["true_start"] - prev_card["true_end"]
                
                # FIXED-TIME GAP CHECK: If gap is smaller than max_gap_seconds, chain normally.
                # If gap is larger or equal, suppress early preview and insert [Instruments].
                if gap_before < max_gap_seconds:
                    inc_s = prev_card["true_start"]
                    if ci >= 2:
                        prev_same = cards[ci - 2]
                        if inc_s < prev_same["true_end"]:
                            inc_s = prev_same["true_end"]
                else:
                    inc_s = card["true_start"] - 2.0
                    # Insert [Instruments] card during the solo/long break
                    inst_start = prev_card["true_end"] + 0.5
                    inst_end = card["true_start"] - 2.0
                    if inst_end > inst_start + 1.0:
                        content_lines.append(f"Dialogue: 0,{format_to_ass_time(inst_start)},{format_to_ass_time(inst_end)},Title,,0,0,0,,[Instruments]\n")
                    
                if inc_e > inc_s:
                    content_lines.append(f"Dialogue: 0,{format_to_ass_time(inc_s)},{format_to_ass_time(inc_e)},{slot},,0,0,0,,{fut_ov}{card_text}\n")
                content_lines.append(f"Dialogue: 1,{format_to_ass_time(card['true_start'])},{format_to_ass_time(card['true_end'])},{slot},,0,0,0,,{past_ov}{payload_k}\n")

    try:
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.writelines(content_lines)
            
        if not os.path.exists(out_path) or os.path.getsize(out_path) == 0:
            print(f"❌ FATAL ERROR: ASS file write verification failed: {out_path}", file=sys.stderr)
            sys.exit(1)
            
        print(f"✅ Final ASS generated at {out_path}")
    except Exception as e:
        print(f"❌ CRITICAL I/O ERROR: Failed to write ASS file '{out_path}': {e}", file=sys.stderr)
        sys.exit(1)

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
    try:
        with open(gender_json_path, "w", encoding="utf-8") as gf:
            json.dump(sections, gf, indent=2)
    except Exception:
        pass

    if assets_path:
        try:
            with open(assets_path, "r", encoding="utf-8") as dbf:
                assets_data = json.load(dbf)
            project_root = os.path.dirname(assets_path)
            inputs_sub_dir = os.path.join(project_root, "inputs", "Subtitles")
            os.makedirs(inputs_sub_dir, exist_ok=True)
            target_inputs_ass = os.path.join(inputs_sub_dir, os.path.basename(out_path))
            shutil.copyfile(out_path, target_inputs_ass)
            
            rel_sub_path = os.path.relpath(target_inputs_ass, project_root)
            if "inputs" not in assets_data:
                assets_data["inputs"] = {}
            assets_data["inputs"]["subtitles_ass"] = rel_sub_path
            assets_data["inputs"]["subtitles_production_ass"] = rel_sub_path
            with open(assets_path, "w", encoding="utf-8") as dbf:
                json.dump(assets_data, dbf, indent=4)
        except Exception:
            pass

def write_midi_report(source_path, out_path, midi_file, tokens, tempo_events, preview_path=None, report_path=None, source_type="midi"):
    report_path = report_path or os.path.splitext(out_path)[0] + ".report.txt"
    report_dir = os.path.dirname(os.path.abspath(report_path))
    if report_dir:
        os.makedirs(report_dir, exist_ok=True)
    lines = [f"Source report for: {source_path}", f"ASS output: {out_path}", f"- source type: {source_type}", ""]
    if midi_file is not None:
        from karaoke.parser import parse_time_signatures
        time_sigs = parse_time_signatures(midi_file)
        lines.append(f"- time signatures found: {len(time_sigs)}")
    lines.append(f"- tokens extracted: {len(tokens)}")
    lines.append(f"- tempo markers: {len(tempo_events)}")
    if preview_path:
        lines.append(f"- preview JSON: {preview_path}")
    try:
        with open(report_path, "w", encoding="utf-8") as rf:
            rf.write("\n".join(lines) + "\n")
    except Exception:
        pass

def write_preview_json(source_path, out_path, tokens, preview_path, tempo_events, target_bpm=120.0, source_type="midi"):
    from karaoke.cards import group_cards
    cards = group_cards(tokens)
    tempo_data = [{"tick": t, "tempo": tempo, "bpm": mido.tempo2bpm(tempo)} for t, tempo in tempo_events] if source_type == "midi" else [{"quarter": q, "bpm": bpm} for q, bpm in tempo_events]
    preview_data = {
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "source_path": source_path,
        "source_type": source_type,
        "ass_path": out_path,
        "target_bpm": target_bpm,
        "tempo_events": tempo_data,
        "tokens": [{"text": tok["text"].strip(), "start_time": tok["start_time"], "end_time": tok["end_time"], "card_break": tok["card_break"], "style_tag": tok.get("style_tag")} for tok in tokens],
        "cards": [{"index": i+1, "token_count": len(c["tokens"]), "style_tag": c.get("style_tag", "default"), "text": "".join([t["text"].strip() + " " for t in c["tokens"]]).strip(), "start_time": c["true_start"], "end_time": c["true_end"]} for i, c in enumerate(cards)],
    }
    if source_type == "midi":
        preview_data["midi_path"] = source_path
    try:
        with open(preview_path, "w", encoding="utf-8") as pf:
            json.dump(preview_data, pf, indent=2, ensure_ascii=False)
    except Exception:
        pass