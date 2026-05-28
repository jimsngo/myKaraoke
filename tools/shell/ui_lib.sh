#!/bin/bash
display_menu() {
    clear
    echo "----------------------------------------------------------------"
    echo "             ✝️  Karaoke_Dashboard v4.6 (Stable) ✝️              "
    echo "----------------------------------------------------------------"
    echo "Active Assets:"
    # This now iterates over the flat keys in assets.json
    jq -r 'to_entries[] | "  \(.key): \(.value)"' "$PRESETS"
    echo "----------------------------------------------------------------"
    echo " 1) Import Assets"
    echo " 2) Create Karaoke"
    echo " 3) Lyrics"
    echo " 4) Push"
    echo " -- Media Tools --"
    echo " 6) Max Volume"
    echo " 7) Scan Loudness"
    echo " 8) Strip Audio"
    echo " 9) Overlay Animation"
    echo " 10) Exit"
    echo " 11) Purge Outputs"
    echo "----------------------------------------------------------------"
}