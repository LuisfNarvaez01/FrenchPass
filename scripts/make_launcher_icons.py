"""Builds FrenchPass launcher icons from the mascot sticker.

usage: python scripts/make_launcher_icons.py <mascot.png> android/app/src/main/res <preview dir> [bg hex]
"""
import os, sys
from PIL import Image, ImageDraw

src, res, preview = sys.argv[1], sys.argv[2], sys.argv[3]
bg_hex = sys.argv[4] if len(sys.argv) > 4 else 'C49A3C'
bg = tuple(int(bg_hex[i:i+2], 16) for i in (0, 2, 4)) + (255,)

mascot = Image.open(src).convert('RGBA')
mascot = mascot.crop(mascot.getbbox())

def place(canvas_px, art_frac, y_shift=0.0):
    """Mascot centred on a transparent square, its longer side art_frac of it."""
    canvas = Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
    side = round(canvas_px * art_frac)
    w, h = mascot.size
    scale = side / max(w, h)
    art = mascot.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    x = (canvas_px - art.width) // 2
    y = (canvas_px - art.height) // 2 + round(canvas_px * y_shift)
    canvas.alpha_composite(art, (x, y))
    return canvas

densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, d in densities.items():
    folder = os.path.join(res, f'mipmap-{name}')
    os.makedirs(folder, exist_ok=True)
    # Adaptive foreground: 108dp canvas; launchers show the middle ~72dp and
    # mask to as little as a 66dp circle, so the art spans ~70dp.
    place(round(108 * d), 0.65).save(os.path.join(folder, 'ic_launcher_foreground.png'))
    # Legacy (pre-API 26 and some launchers): round badge, 48dp.
    px = round(48 * d)
    big = px * 4
    legacy = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    legacy.paste(Image.new('RGBA', (big, big), bg), (0, 0), mask)
    legacy.alpha_composite(place(big, 0.86))
    legacy.resize((px, px), Image.LANCZOS).save(os.path.join(folder, 'ic_launcher.png'))

# Previews: what a circle-masking and a squircle-masking launcher show.
os.makedirs(preview, exist_ok=True)
fg = place(432, 0.65)
full = Image.new('RGBA', (432, 432), bg)
full.alpha_composite(fg)
inner = full.crop((36, 36, 396, 396))  # the visible 72dp viewport... roughly
for shape in ('circle', 'squircle'):
    m = Image.new('L', inner.size, 0)
    d = ImageDraw.Draw(m)
    if shape == 'circle':
        d.ellipse((0, 0, inner.width - 1, inner.height - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, inner.width - 1, inner.height - 1), radius=110, fill=255)
    out = Image.new('RGBA', inner.size, (255, 255, 255, 255))
    out.paste(inner, (0, 0), m)
    out.save(os.path.join(preview, f'preview_{shape}.png'))
