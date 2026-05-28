#!/bin/bash
overlay_pulse() {
    local bg="$1"
    local fg="$2"
    local output="$PROJECT_DIR/outputs/looping_background.mp4"
    
    ffmpeg -y -stream_loop -1 -i "$bg" -stream_loop -1 -i "$fg" \
    -filter_complex "[1:v]format=yuva420p[fg];[0:v][fg]overlay=(W-w)/2:(H-h)/2:format=auto" \
    -c:v libx264 -crf 18 -pix_fmt yuv420p -t 300 "$output"
}