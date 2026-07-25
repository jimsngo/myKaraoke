#!/usr/bin/env python3
"""
Cards & Styling Module for Karaoke Pipeline.
Manages lyric segmentation, card boundaries, font sizing, and style sidecars.
Includes strict validation and fail-safe exit guards.
"""

import os
import sys
import shutil

def group_cards(raw_tokens, max_tokens=None):
    if not isinstance(raw_tokens, list):
        print(f"❌ FATAL ERROR: group_cards expected a list of tokens, got {type(raw_tokens)}", file=sys.stderr)
        sys.exit(1)
        
    cards = []
    current = []
    for i, tok in enumerate(raw_tokens):
        if current:
            reached_token_limit = (max_tokens is not None and len(current) >= max_tokens)
            if current[-1].get("card_break", False) or reached_token_limit:
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
    if not isinstance(raw_tokens, list):
        print(f"❌ FATAL ERROR: group_logical_cards expected a list of tokens, got {type(raw_tokens)}", file=sys.stderr)
        sys.exit(1)
        
    cards = []
    cur = []
    start_idx = 0
    for i, t in enumerate(raw_tokens):
        if not cur:
            start_idx = i
        cur.append(t)
        if t.get("card_break"):
            cards.append({
                "tokens": cur, 
                "true_start": cur[0]["start_time"], 
                "true_end": cur[-1]["end_time"], 
                "start_token": start_idx + 1, 
                "end_token": i + 1
            })
            cur = []
    if cur:
        cards.append({
            "tokens": cur, 
            "true_start": cur[0]["start_time"], 
            "true_end": cur[-1]["end_time"], 
            "start_token": start_idx + 1, 
            "end_token": len(raw_tokens)
        })
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

def write_styles_sidecar(cards, out_path, gender_selection="Male", assets_path=None):
    try:
        base = os.path.splitext(out_path)[0]
        styles_path = base + ".styles.txt"
        
        raw_gender = gender_selection.strip().lower()
        if raw_gender == "female":
            default_gender = "F"
        elif raw_gender == "duet":
            default_gender = "D"
        else:
            default_gender = "M"
            
        with open(styles_path, "w", encoding="utf-8") as fh:
            fh.write("# Auto-generated styles sidecar from cards.py\n")
            fh.write("# Edit this file and re-run to apply gender overrides.\n")
            fh.write(f"default = {default_gender}\n\n")
            for idx, card in enumerate(cards, start=1):
                tag = card.get("style_tag")
                gender_char = 'F' if tag == 'female' else ('D' if tag == 'duet' else 'M')
                fh.write(f"{idx} = {gender_char}\n")
        
        if assets_path and os.path.exists(assets_path):
            inputs_dir = os.path.join(os.path.dirname(os.path.abspath(assets_path)), "inputs", "Subtitles")
            os.makedirs(inputs_dir, exist_ok=True)
            target_path = os.path.join(inputs_dir, os.path.basename(styles_path))
            if os.path.abspath(styles_path) != os.path.abspath(target_path):
                shutil.copyfile(styles_path, target_path)
        
        print(f"📝 Wrote styles sidecar: {styles_path}")
    except Exception as e:
        print(f"❌ CRITICAL ERROR: Failed to write styles sidecar '{out_path}': {e}", file=sys.stderr)
        sys.exit(1)

def parse_styles_file(path):
    out = {}
    if not path or not os.path.exists(path):
            return out
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
                    
                    if right.startswith("f"):
                        gender_tag = "female"
                    elif right.startswith("d"):
                        gender_tag = "duet"
                    else:
                        gender_tag = "male"
                        
                    if left == "default":
                        out[0] = gender_tag
                    else:
                        try:
                            idx = int(left)
                            out[idx] = gender_tag
                        except Exception:
                            pass
    except Exception as e:
        print(f"⚠️ Warning: Failed to parse styles file '{path}': {e}", file=sys.stderr)
    return out