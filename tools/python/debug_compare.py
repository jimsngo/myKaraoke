#!/usr/bin/env python3
"""
Debug Tool: Compares preview.json token timestamps against compiled .ass Dialogue: 1 timing tags.
Includes absolute highlight-on timestamps.
"""

import os
import sys
import json
import re

def ass_time_to_seconds(time_str):
    parts = time_str.split(':')
    h = int(parts[0])
    m = int(parts[1])
    s = float(parts[2])
    return h * 3600 + m * 60 + s

def parse_ass_dialogues(ass_path):
    tokens_from_ass = []
    if not os.path.exists(ass_path):
        return tokens_from_ass
    
    with open(ass_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("Dialogue: 1,"):
                parts = line.split(",", 9)
                if len(parts) < 10:
                    continue
                start_str = parts[1].strip()
                text = parts[9].strip()
                
                line_start_sec = ass_time_to_seconds(start_str)
                k_matches = list(re.finditer(r"\{\\k(\d+)\}([^\{\/\\]*)", text))
                current_offset_cs = 0
                
                for m in k_matches:
                    duration_cs = int(m.group(1))
                    token_text = m.group(2).strip()
                    if not token_text:
                        current_offset_cs += duration_cs
                        continue
                        
                    tok_start_sec = line_start_sec + (current_offset_cs / 100.0)
                    current_offset_cs += duration_cs
                    tok_end_sec = line_start_sec + (current_offset_cs / 100.0)
                    
                    tokens_from_ass.append({
                        "text": token_text,
                        "start_time": tok_start_sec,
                        "end_time": tok_end_sec
                    })
    return tokens_from_ass

def main():
    base_dir = "inputs/Subtitles"
    files = os.listdir(base_dir) if os.path.exists(base_dir) else []
    ass_files = [f for f in files if f.endswith(".ass") and not f.endswith("production.ass")]
    
    if not ass_files:
        print("❌ No ASS files found in inputs/Subtitles/")
        sys.exit(1)
        
    target_base = os.path.splitext(ass_files[0])[0]
    ass_path = os.path.join(base_dir, f"{target_base}.ass")
    json_path = os.path.splitext(ass_path)[0] + ".preview.json"
    
    if not os.path.exists(json_path):
        sys.exit(1)
        
    with open(json_path, "r", encoding="utf-8") as f:
        preview_data = json.load(f)
        
    json_tokens = preview_data.get("tokens", [])
    ass_tokens = parse_ass_dialogues(ass_path)
    
    print(f"{'Idx':<4} | {'Token Text':<12} | {'JSON Start':<10} | {'ASS Start':<10} | {'Highlight On (Abs)':<18} | {'Delta':<8}")
    print("-" * 75)
    
    min_len = min(len(json_tokens), len(ass_tokens))
    for i in range(min_len):
        jt = json_tokens[i]
        at = ass_tokens[i]
        delta = at["start_time"] - jt["start_time"]
        highlight_abs = at["start_time"]  # The absolute seconds mark when color sweep hits the token
        
        flag = " ⚠️" if abs(delta) > 0.1 else ""
        print(f"{i+1:<4} | {jt['text']:<12} | {jt['start_time']:<10.3f} | {at['start_time']:<10.3f} | {highlight_abs:<18.3f} | {delta:<+.3f}{flag}")

if __name__ == "__main__":
    main()