"""Cuts a mascot sticker out of its flat background.

usage: python scripts/cut_mascot.py <input.png> <output.png> [size]

The artwork is a sticker (white outline) on a flat gold field. Everything
connected to the image border that is close to that gold becomes
transparent; the white outline stops the fill, so nothing inside the
sticker is touched. The result is cropped to the sticker and scaled so its
longer side is `size` pixels (default 512).
"""
import sys
from collections import deque

from PIL import Image, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 512

image = Image.open(src).convert('RGBA')
w, h = image.size
px = image.load()

# The field's colour, sampled from the four corners.
corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
TOLERANCE = 70 ** 2


def is_bg(c):
    return sum((c[i] - bg[i]) ** 2 for i in range(3)) <= TOLERANCE


mask = Image.new('L', (w, h), 255)
m = mask.load()
queue = deque()
for x in range(w):
    queue.append((x, 0))
    queue.append((x, h - 1))
for y in range(h):
    queue.append((0, y))
    queue.append((w - 1, y))
while queue:
    x, y = queue.popleft()
    if m[x, y] == 0 or not is_bg(px[x, y]):
        continue
    m[x, y] = 0
    if x > 0:
        queue.append((x - 1, y))
    if x < w - 1:
        queue.append((x + 1, y))
    if y > 0:
        queue.append((x, y - 1))
    if y < h - 1:
        queue.append((x, y + 1))

# Eat the gold fringe the anti-aliased outline leaves, then soften the edge.
mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
image.putalpha(mask)
image = image.crop(mask.getbbox())

scale = size / max(image.size)
image = image.resize((round(image.width * scale), round(image.height * scale)),
                     Image.LANCZOS)
image.save(dst, optimize=True)
print(dst, image.size)
