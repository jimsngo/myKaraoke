# 🎤 myKaraoke Voyage Control

A streamlined, automated karaoke video production system designed for **Sunday Mass** and personal music projects. This workflow integrates **Logic Pro** audio exports and **Aegisub** subtitles with a powerful **FFmpeg** rendering engine.

## 🛠️ Core Components
* **`karaoke_control.sh`**: The main terminal interface (Controller).
* **`tools/shell/create_video.sh`**: The FFmpeg engine that handles image animation (Voyage Engine) and video layering.
* **`tools/python/color_karaoke.py`**: Automates the Blue → White → Gray subtitle transitions.

## 🚀 How to Use
1.  **Prepare Assets**: Export your Vocal and Backing tracks from **Logic Pro**.
2.  **Time Lyrics**: Create word-by-word timing in **Aegisub** and save as `.ass`.
3.  **Run Controller**: Launch `./karaoke_control.sh` from the terminal.
4.  **Follow the Menu**:
    * **Option 1**: Select your files and render the video.
    * **Option 2**: Sync your latest script changes to GitHub.

## 📁 Repository Structure
* `/config`: Project and color settings.
* `/media-tools`: Documentation for FFmpeg and MPV usage.
* `/tools`: The Python and Shell "workers" that do the heavy lifting.

---
*Created by Jim - Optimized for Sunday Mass Worship.*
