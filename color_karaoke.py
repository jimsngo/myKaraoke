import re
import sys

def convert_line(line):
    # Only process actual lyric lines with karaoke tags
    if not line.startswith("Dialogue:") or "{\\k" not in line:
        return line
    
    try:
        # Split the ASS header from the actual text content
        header, text_content = line.split(",,", 1)
        # Split the text content into karaoke tags and words
        parts = re.split(r'(\{\\k\d+\})', text_content)
    except ValueError:
        return line
        
    new_text = "{\\1c&H0000FF&}" # Set initial word to Blue
    
    for part in parts:
        if part.startswith('{\\k'):
            # Convert \k duration to milliseconds (Aegisub uses centiseconds)
            dur_match = re.search(r'\d+', part)
            if dur_match:
                dur = int(dur_match.group()) * 10
                # Transition: White while singing, snap to Gray at the exact end
                new_text += f"{{\\t(0,{dur},\\1c&HFFFFFF&)}}{{\\t({dur},{dur},\\1c&H808080&)}}"
        elif part.strip(): # If it's actual text
            # Add the word text, then prep the Blue color for the next word
            new_text += part + "{\\1c&H0000FF&}"
        else:
            new_text += part
            
    return f"{header},,{new_text}\n"

# --- Main Script Execution ---
if len(sys.argv) < 2:
    print("Usage: python3 color_karaoke.py your_file.ass")
else:
    input_file = sys.argv[1]
    output_file = input_file.replace(".ass", "_colored.ass")
    
    try:
        # Open with utf-8-sig to handle Mac/Aegisub BOMs
        with open(input_file, 'r', encoding='utf-8-sig') as f:
            lines = f.readlines()
            
        with open(output_file, 'w', encoding='utf-8') as f:
            for line in lines:
                f.write(convert_line(line))
        print(f"✅ Success! Created: {output_file}")
    except Exception as e:
        print(f"❌ Error: {e}")