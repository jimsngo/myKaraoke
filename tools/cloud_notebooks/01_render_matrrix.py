import json
import os
import sys
import subprocess
import re
import shutil
import unicodedata

# ==============================================================================
# 🎛️ CLOUD TOOLCHAIN INTERACTIVE CONTROL PANEL
# ==============================================================================
#@title 🎵 Choose Your Render Action { display-mode: "form" }
ACTION_SELECT = "9 - Generate Instrumental Karaoke Video" #@param ["8 - Import & Optimize Background Scenery", "9 - Generate Instrumental Karaoke Video", "10 - Generate Full Mix Lyrics Presentation"] {type:"string"}
# ==============================================================================

# 1. Environment Configurations
mac_folder_name = "My iMac"  
cloud_project_root = f'/content/drive/Othercomputers/{mac_folder_name}/myKaraoke'
scratch_dir = "/content/scratch_space"

print(f"📁 Navigating to cloud project root: {cloud_project_root}")
os.makedirs(scratch_dir, exist_ok=True)
os.chdir(cloud_project_root)

def find_true_path(root, relative_path):
    if not relative_path: return ""
    parts = relative_path.strip('/').split('/')
    current = root
    resolved_parts = []
    for part in parts:
        if not part: continue
        part_norm = unicodedata.normalize('NFC', part).lower()
        if os.path.isdir(current):
            items = os.listdir(current)
            matched = None
            for item in items:
                if unicodedata.normalize('NFC', item).lower() == part_norm:
                    matched = item
                    break
            resolved_parts.append(matched if matched else part)
            current = os.path.join(current, matched if matched else part)
        else:
            resolved_parts.append(part)
            current = os.path.join(current, part)
    return '/'.join(resolved_parts)

def collapse_repeated_path(path):
    """Fix accidental duplicated path prefixes, e.g. inputs/mixed/inputs/mixed/file.mp3."""
    if not path:
        return ""
    clean = path.strip('/')
    parts = clean.split('/')
    for size in range(1, len(parts) // 2 + 1):
        if parts[:size] == parts[size:2 * size]:
            return '/'.join(parts[size:])
    return clean

def first_existing_relative_path(root, candidates):
    """Return the first candidate path that resolves to an existing file."""
    for candidate in candidates:
        if not candidate:
            continue

        # Try as-is (case tolerant)
        resolved = find_true_path(root, candidate)
        abs_path = os.path.join(root, resolved)
        if os.path.exists(abs_path):
            return candidate, abs_path

        # Try with collapsed duplicate prefixes
        collapsed = collapse_repeated_path(candidate)
        if collapsed != candidate:
            resolved_collapsed = find_true_path(root, collapsed)
            abs_collapsed = os.path.join(root, resolved_collapsed)
            if os.path.exists(abs_collapsed):
                return collapsed, abs_collapsed

    return "", ""

# 2. Parse Project Configurations
with open('assets.json', 'r') as f:
    config = json.load(f)

raw_title = config['inputs'].get('song_title', 'project_output')
song_name = re.sub(r'[\s_]+', '_', raw_title).strip('_')

if "8 -" in ACTION_SELECT:
    RUN_OPTION = 8
    print(f"\n🚀 RUNNING CLOUD ENGINE: OPTIMIZE BACKGROUND")
    audio_candidates = [
        config['inputs'].get('mixed_audio'),
        config['inputs'].get('instruments_only')
    ]
    dest_filename = f"{song_name}_optimized_background.mp4"
    final_gdrive_dir = os.path.join(cloud_project_root, "outputs/Background")
elif "9 -" in ACTION_SELECT:
    RUN_OPTION = 9
    print(f"\n🚀 RUNNING CLOUD ENGINE: KARAOKE GENERATOR")
    audio_candidates = [config['inputs'].get('instruments_only')]
    dest_filename = f"{song_name}_karaoke.mp4"
    final_gdrive_dir = os.path.join(cloud_project_root, "outputs/Karaoke")
elif "10 -" in ACTION_SELECT:
    RUN_OPTION = 10
    print(f"\n🚀 RUNNING CLOUD ENGINE: FULL MIX LYRICS")
    audio_candidates = [
        config['inputs'].get('mixed_audio'),
        config['inputs'].get('instruments_only')
    ]
    dest_filename = f"{song_name}_lyrics.mp4"
    final_gdrive_dir = os.path.join(cloud_project_root, "outputs/Lyrics")

audio_rel, src_audio_track = first_existing_relative_path(cloud_project_root, audio_candidates)
if not src_audio_track:
    print("\n❌ Could not resolve an existing audio track for this action.")
    print("   Checked candidates:")
    for c in audio_candidates:
        if c:
            print(f"   - {c}")
    sys.exit(1)

if config['inputs'].get('mixed_audio') and audio_rel != config['inputs'].get('mixed_audio'):
    print(f"   ⚠️  mixed_audio path unavailable; falling back to: {audio_rel}")

total_duration = None
try:
    probe_cmd = f"ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 '{src_audio_track}'"
    total_duration = float(subprocess.check_output(probe_cmd, shell=True).strip())
except Exception as e:
    print(f"\n❌ Unable to probe audio duration from: {src_audio_track}")
    print(f"   ffprobe error: {e}")
    sys.exit(1)

if total_duration is None or total_duration <= 0:
    print(f"\n❌ Invalid audio duration detected: {total_duration}")
    sys.exit(1)

opt_bg_filename = f"{song_name}_optimized_background.mp4"
opt_bg_gdrive_path = os.path.join(cloud_project_root, "outputs/Background", opt_bg_filename)

if RUN_OPTION in [9, 10] and os.path.exists(opt_bg_gdrive_path):
    src_bg = opt_bg_gdrive_path
    print("   ✨ Smart Routing active: Pre-rendered background locked.")
else:
    src_bg = os.path.join(cloud_project_root, find_true_path(cloud_project_root, config['inputs']['background']))

local_bg = os.path.join(scratch_dir, os.path.basename(src_bg))
local_output = os.path.join(scratch_dir, dest_filename)

print("   📦 Syncing video background element...")
shutil.copy2(src_bg, local_bg)

if RUN_OPTION in [9, 10]:
    sub_key = config['inputs'].get('subtitles_production_ass') or config['inputs']['subtitles_ass']
    src_sub = os.path.join(cloud_project_root, find_true_path(cloud_project_root, sub_key))
    
    local_audio = os.path.join(scratch_dir, os.path.basename(src_audio_track))
    local_sub = os.path.join(scratch_dir, os.path.basename(src_sub))
    
    shutil.copy2(src_audio_track, local_audio)
    shutil.copy2(src_sub, local_sub)
    
    # Sync gender sections and icons for overlay rendering (Karaoke mode only)
    if RUN_OPTION == 9:
        src_gender_sections = os.path.join(cloud_project_root, 'inputs/text/gender_sections.json')
        local_gender_sections = os.path.join(scratch_dir, 'gender_sections.json')
        if os.path.exists(src_gender_sections):
            shutil.copy2(src_gender_sections, local_gender_sections)
        
        icon_names = ['male_icon.png', 'female_icon.png', 'duet_icon.png']
        local_icons = {}
        for icon in icon_names:
            src_icon = os.path.join(cloud_project_root, f'inputs/icons/{icon}')
            local_icon = os.path.join(scratch_dir, icon)
            if os.path.exists(src_icon):
                shutil.copy2(src_icon, local_icon)
                local_icons[icon] = local_icon

print("✅ Local scratch memory mounted!")

# 4. Enforce High-Fidelity Font Environments
print("   🔤 Installing Vietnamese-compatible font packages...")
subprocess.run(["apt-get", "update", "-y"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
# Install multiple font packages for better Vietnamese support
subprocess.run(["apt-get", "install", "-y", "fonts-liberation", "fonts-dejavu", "fonts-noto"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

if RUN_OPTION in [9, 10]:
    print("   📝 Normalizing subtitle text and mapping fonts...")
    with open(local_sub, 'r', encoding='utf-8') as f_sub:
        sub_content = f_sub.read()
    
    clean_title = config['inputs'].get('song_title', 'Unknown').replace('_', ' ')
    clean_author = config['inputs'].get('song_author', 'Unknown').replace('_', ' ')
    
    sub_content = re.sub(r'(Dialogue: 0,0:00:00.00,.*?,Title,,0,0,0,,{.*?}).*', rf'\1{clean_title}\\N{{\\fs50}}{clean_author}', sub_content)
    
    # 💡 SMART FONT MAPPING FOR COLAB COMPATIBILITY
    # Map Arial (Mac font) to DejaVu Sans (Colab available, full Vietnamese support)
    # This preserves the original font intent while ensuring compatibility
    sub_content = re.sub(r'(Style:\s*[^,]+,)\s*Arial\s*,', r'\1DejaVu Sans,', sub_content, flags=re.IGNORECASE)
    
    # Force full text normalization to prevent dropped characters
    sub_content = unicodedata.normalize('NFC', sub_content)
    
    with open(local_sub, 'w', encoding='utf-8') as f_sub:
        f_sub.write(sub_content)

# 5. Tuned Production Quality Profiles (Optimized Bitrates)
if RUN_OPTION == 8:
    ffmpeg_cmd = [
        'ffmpeg', '-y', '-nostdin',
        '-stream_loop', '-1',
        '-i', local_bg,
        '-t', f"{total_duration:.2f}",
        '-vf', 'scale=1920:1080,fps=30',
        '-c:v', 'h264_nvenc', '-preset', 'p4', '-rc', 'vbr', '-cq', '28',
        '-pix_fmt', 'yuv420p',
        '-an',
        local_output
    ]
elif RUN_OPTION == 9:
    # 💡 KARAOKE RENDER: Subtitles + Overlay Icons based on Gender Sections
    # Build dynamic filter_complex with icon overlays
    filter_parts = [f"[0:v]subtitles={local_sub}[v_sub]"]
    input_index = 2  # Start after background (0) and audio (1)
    
    # Load gender sections and build overlay filters
    gender_map = {'male': 'male_icon.png', 'female': 'female_icon.png', 'duet': 'duet_icon.png'}
    icon_inputs = []
    overlay_filters = []
    
    if os.path.exists(local_gender_sections):
        with open(local_gender_sections, 'r') as f:
            gender_sections = json.load(f)
        
        for idx, section in enumerate(gender_sections):
            gender = section.get('gender', 'male')
            start = section.get('start', 0)
            end = section.get('end', total_duration)
            
            icon_file = gender_map.get(gender, 'male_icon.png')
            icon_path = local_icons.get(icon_file)
            
            if icon_path and os.path.exists(icon_path):
                # Input pad for this icon
                input_pad = f"[{input_index}]"
                icon_inputs.append(['-i', icon_path])
                
                # Determine icon positioning based on gender
                if gender == 'duet':
                    x_pos, y_pos = '20', '440'  # Duet icon positioned higher
                else:
                    x_pos, y_pos = '20', '475'  # Single gender icons
                
                # Overlay filter with timing enable
                prev_pad = f"[v_sub]" if idx == 0 else f"[v_overlay_{idx-1}]"
                overlay_filters.append(
                    f"{prev_pad}{input_pad}overlay={x_pos}:{y_pos}:enable='between(t,{start},{end})'[v_overlay_{idx}]"
                )
                input_index += 1
        
        # Build final filter_complex
        if overlay_filters:
            filter_parts.extend(overlay_filters)
            filter_complex = ";".join(filter_parts)
            final_pad = f"[v_overlay_{len(overlay_filters)-1}]"
        else:
            filter_complex = ";".join(filter_parts)
            final_pad = "[v_sub]"
    else:
        filter_complex = ";".join(filter_parts)
        final_pad = "[v_sub]"
    
    # Build ffmpeg command
    ffmpeg_cmd = ['ffmpeg', '-y', '-nostdin', '-i', local_bg, '-i', local_audio]
    
    # Add icon inputs
    if icon_inputs:
        for icon_input in icon_inputs:
            ffmpeg_cmd.extend(icon_input)
    
    # Add filter complex and mappings
    ffmpeg_cmd.extend([
        '-filter_complex', filter_complex,
        '-map', f'{final_pad}',
        '-map', '1:a:0',
        '-c:v', 'h264_nvenc', '-preset', 'p4', '-rc', 'vbr', '-cq', '25',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '192k',
        '-shortest',
        local_output
    ])
else:
    # 💡 FULL MIX LYRICS: Simple subtitle render without overlays
    ffmpeg_cmd = [
        'ffmpeg', '-y', '-nostdin',
        '-i', local_bg,
        '-i', local_audio,
        '-vf', f"subtitles={local_sub}",
        '-map', '0:v:0',   
        '-map', '1:a:0',   
        '-c:v', 'h264_nvenc', '-preset', 'p4', '-rc', 'vbr', '-cq', '25',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '192k',
        '-shortest',
        local_output
    ]

print("\n🎬 Executing Accelerated GPU Render Sequence...")
process = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

print(f"⏱️  Timeline Target: {total_duration:.2f}s")
print("="*60 + "\n🎬 VIDEO PROCESSING MONITOR MATRIX\n" + "="*60)

for line in process.stdout:
    line_str = line.strip()
    if "time=" in line_str:
        time_match = re.search(r'time=(\d+):(\d+):(\d+\.\d+)', line_str)
        if time_match:
            hours, minutes, seconds = map(float, time_match.groups())
            current_seconds = (hours * 3600) + (minutes * 60) + seconds
            percent = min(100.0, (current_seconds / total_duration) * 100)
            bar_length = int(30 * percent // 100)
            progress_bar = '█' * bar_length + '░' * (30 - bar_length)
            speed_match = re.search(r'speed=\s*([\d.]+x)', line_str)
            speed_str = speed_match.group(1) if speed_match else "N/A"
            sys.stdout.write(f"\r⚡ [{progress_bar}] {percent:.1f}% | Processed: {current_seconds:.1f}s / {total_duration:.2f}s | Speed: {speed_str}")
            sys.stdout.flush()

process.wait()

if process.returncode == 0 and os.path.exists(local_output):
    os.makedirs(final_gdrive_dir, exist_ok=True)
    gdrive_destination = os.path.join(final_gdrive_dir, dest_filename)
    print(f"\n\n📦 Mirroring completed video file back to Drive storage node...")
    shutil.copy2(local_output, gdrive_destination)
    print(f"✨ Success! Saved to: {gdrive_destination.replace(cloud_project_root, '')}")
    
    if RUN_OPTION == 8:
        try:
            relative_bg_path = f"outputs/Background/{dest_filename}"
            with open('assets.json', 'r') as db_file:
                assets_data = json.load(db_file)
            assets_data['inputs']['background'] = relative_bg_path
            if 'outputs' not in assets_data: assets_data['outputs'] = {}
            assets_data['outputs']['background_video'] = relative_bg_path
            with open('assets.json', 'w') as db_file:
                json.dump(assets_data, db_file, indent=4)
        except Exception as e:
            print(f"⚠️ Warning: Configuration sync error: {e}")
else:
    print("\n❌ Processing error: Render core terminated abnormally.")