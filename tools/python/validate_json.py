#!/usr/bin/env python3
# Central Utility: tools/python/validate_json.py
# Purpose: Guard Python scripts from key drift and suggest closest file-type matches

import os
import sys
import json

# Terminal Colors
RED = '\033[0;31m'
YELLOW = '\033[0;33m'
CYAN = '\033[0;36m'
NC = '\033[0;0m'

def validate_required_keys(calling_script, required_keys):
    assets_file = "/Users/jim/myKaraoke/assets.json"
    broken_keys = 0

    if not os.path.exists(assets_file):
        print(f"{RED}❌ System Error: assets.json missing at {assets_file}{NC}")
        sys.exit(1)

    try:
        with open(assets_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"{RED}❌ System Error: Failed to parse assets.json ({str(e)}){NC}")
        sys.exit(1)

    inputs = data.get("inputs", {})
    
    for req_key in required_keys:
        if req_key not in inputs:
            print(f"{RED}⚠️  Key Misalignment Detected in: {calling_script}{NC}")
            print(f"{RED}   Expected Variable Key: \".inputs.{req_key}\" was NOT found in assets.json{NC}")
            
            # Isolate file extension target context
            look_ext = ""
            if "srt" in req_key:
                look_ext = ".srt"
            elif "ass" in req_key:
                look_ext = ".ass"

            # Filter candidates inside assets.json matching that type
            matching_candidates = []
            for k, v in inputs.items():
                if isinstance(v, str) and look_ext:
                    if v.lower().endswith(look_ext):
                        matching_candidates[k] = v
                elif isinstance(v, str):
                    matching_candidates.append(k)

            if matching_candidates:
                # Suggest the primary active key matching the structural extension context
                suggestion = matching_candidates[0] if isinstance(matching_candidates, list) else list(matching_candidates.keys())[0]
                print(f"{CYAN}   👉 Are you referring to \"{suggestion}\", as opposed to \"{req_key}\"?{NC}")
            
            print("--------------------------------------------------------")
            broken_keys += 1

    if broken_keys > 0:
        print(f"{RED}💥 A ha... we have a broken variable schema connection!{NC}")
        print(f"{YELLOW}   Fix the key name alignment before running this task.{NC}")
        print("--------------------------------------------------------")
        sys.exit(1)