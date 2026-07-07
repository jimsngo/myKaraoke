#!/usr/bin/env python3
"""Generate simple microphone icons for karaoke gender overlays."""
import os
from PIL import Image, ImageDraw

MALE_COLOR   = (26,  123, 222, 255)
FEMALE_COLOR = (220,  30,  30, 255)
DUET_COLOR   = (220,  80, 180, 255)
TRANS        = (0, 0, 0, 0)
HIGHLIGHT    = (255, 255, 255, 90)

def draw_mic(draw, cx, top_y, color, width=28, head_h=32, body_h=26, cap_h=5):
    hw      = width // 2
    hw_head = int(hw * 1.35)
    head_top, head_bot = top_y, top_y + head_h
    draw.ellipse([cx-hw_head, head_top, cx+hw_head, head_bot], fill=color)
    for frac in (0.30, 0.52, 0.74):
        y     = int(head_top + frac * head_h)
        x_off = int(hw_head * (1 - abs(frac - 0.52) * 1.4))
        draw.line([(cx-x_off+2, y),(cx+x_off-2, y)], fill=HIGHLIGHT, width=2)
    neck_top, neck_bot = head_bot, head_bot + 5
    draw.rectangle([cx-hw+2, neck_top, cx+hw-2, neck_bot], fill=color)
    body_top, body_bot = neck_bot, neck_bot + body_h
    draw.rectangle([cx-hw, body_top, cx+hw, body_bot], fill=color)
    draw.ellipse([cx-hw-3, body_bot, cx+hw+3, body_bot+cap_h], fill=color)

def make_single(color, size=80):
    img = Image.new('RGBA', (size, size), TRANS)
    draw_mic(ImageDraw.Draw(img), size//2, 4, color)
    return img

def make_duet(color, size=96):
    img = Image.new('RGBA', (size, size), TRANS)
    d   = ImageDraw.Draw(img)
    sp  = size // 4
    draw_mic(d, size//2-sp, 8, color, width=20, head_h=26, body_h=22, cap_h=4)
    draw_mic(d, size//2+sp, 8, color, width=20, head_h=26, body_h=22, cap_h=4)
    return img

out_dir = os.path.join(os.path.dirname(__file__), "..", "..", "inputs", "icons")
os.makedirs(out_dir, exist_ok=True)
for name, img in [
    ("male_icon.png",   make_single(MALE_COLOR)),
    ("female_icon.png", make_single(FEMALE_COLOR)),
    ("duet_icon.png",   make_duet(DUET_COLOR)),
]:
    p = os.path.join(out_dir, name)
    img.save(p)
    print(f"✅ {name}: {img.size}")
