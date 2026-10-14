"""Builds the Google Play listing graphics from the mascot.

usage: python scripts/make_store_assets.py

Writes to docs/play-store/:
  icon-512.png             512x512 app icon (Play rounds the corners itself)
  feature-graphic.png      1024x500 banner shown at the top of the listing

Fonts are Windows' Georgia and Segoe UI; on another OS pass the paths in
FRENCHPASS_SERIF / FRENCHPASS_SANS.
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs', 'play-store')
GOLD = (196, 154, 60)        # AppPalette.gold (dark theme)
INK = (20, 17, 13)           # AppPalette.dark.bg
CREAM = (242, 237, 227)      # AppPalette.dark.textPrimary
MUTED = (168, 152, 128)      # AppPalette.dark.textSecondary

SERIF = os.environ.get('FRENCHPASS_SERIF', r'C:\Windows\Fonts\georgiab.ttf')
SANS = os.environ.get('FRENCHPASS_SANS', r'C:\Windows\Fonts\segoeui.ttf')

mascot = Image.open(os.path.join(ROOT, 'assets', 'images', 'mascot.png')).convert('RGBA')
mascot = mascot.crop(mascot.getbbox())


def fit(image, box):
    w, h = image.size
    scale = min(box[0] / w, box[1] / h)
    return image.resize((round(w * scale), round(h * scale)), Image.LANCZOS)


os.makedirs(OUT, exist_ok=True)

# Icon: same composition as the launcher icon, full-bleed gold square.
icon = Image.new('RGBA', (512, 512), GOLD + (255,))
art = fit(mascot, (420, 420))
icon.alpha_composite(art, ((512 - art.width) // 2, (512 - art.height) // 2))
icon.convert('RGB').save(os.path.join(OUT, 'icon-512.png'))

# Feature graphic: name and promise on the left, mascot on the right.
banner = Image.new('RGBA', (1024, 500), INK + (255,))
draw = ImageDraw.Draw(banner)
draw.ellipse((640, 40, 1060, 460), fill=GOLD + (255,))
art = fit(mascot, (380, 380))
banner.alpha_composite(art, (850 - art.width // 2, 250 - art.height // 2))

title = ImageFont.truetype(SERIF, 84)
body = ImageFont.truetype(SANS, 34)
draw.text((64, 150), 'French', font=title, fill=CREAM)
french_w = draw.textlength('French', font=title)
draw.text((64 + french_w, 150), 'Pass', font=title, fill=GOLD)
draw.text((66, 270), 'Habla francés con un tutor', font=body, fill=CREAM)
draw.text((66, 316), 'que te corrige sin cortarte.', font=body, fill=MUTED)
banner.convert('RGB').save(os.path.join(OUT, 'feature-graphic.png'))
print('ok')
