"""Generates the launcher icons and Google Play graphics (original artwork, drawn with Pillow).
Run:  python3 tools/make_graphics.py     (needs: pip install pillow)"""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SS = 4  # supersampling for smooth edges

def gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img

def ellipse_pts(cx, cy, rx, ry, a0=0, a1=2 * math.pi, n=48):
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * rx, cy + math.sin(a0 + (a1 - a0) * i / n) * ry) for i in range(n + 1)]

def draw_fish(d, cx, cy, s, body=(255, 165, 52), belly=(255, 224, 138), fin=(224, 102, 29), crown=False):
    """Cartoon fish facing right; s = body half-length."""
    d.polygon([(cx - 0.7 * s, cy - 0.14 * s), (cx - 1.55 * s, cy - 0.62 * s), (cx - 1.27 * s, cy), (cx - 1.55 * s, cy + 0.62 * s), (cx - 0.7 * s, cy + 0.14 * s)], fill=fin)
    d.polygon([(cx - 0.5 * s, cy - 0.5 * s), (cx - 0.2 * s, cy - 0.5 * s - 0.6 * s), (cx + 0.35 * s, cy - 0.5 * s)], fill=fin)
    out = ellipse_pts(cx, cy, s * 1.08, s * 0.67)
    d.polygon(out, fill=tuple(int(c * 0.7) for c in fin))
    d.polygon(ellipse_pts(cx, cy, s, s * 0.62), fill=body)
    d.polygon(ellipse_pts(cx, cy, s, s * 0.62, 0, math.pi, 24), fill=belly)
    d.polygon([(cx + 0.15 * s, cy + 0.18 * s), (cx - 0.45 * s, cy + 0.55 * s), (cx - 0.05 * s, cy + 0.1 * s)], fill=fin)
    ex, ey, er = cx + 0.55 * s, cy - 0.22 * s, 0.2 * s
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill="white")
    d.ellipse([ex - er * 0.45 + 0.06 * s, ey - er * 0.55, ex + er * 0.65 + 0.06 * s, ey + er * 0.55], fill=(20, 20, 30))
    d.line([(cx + 0.97 * s, cy + 0.08 * s), (cx + 0.72 * s, cy + 0.12 * s)], fill=(60, 20, 20), width=max(2, int(s * 0.05)))
    if crown:
        gold = (255, 214, 51)
        ty = cy - 0.55 * s
        for k in range(3):
            kx = cx + (0.12 + 0.17 * k) * 1.0 * s
            d.polygon([(kx - 0.09 * s, ty), (kx, ty - 0.34 * s), (kx + 0.09 * s, ty)], fill=gold)

def bubbles(d, w, h, n, seed=3):
    r = random.Random(seed)
    for _ in range(n):
        x, y, rad = r.uniform(0, w), r.uniform(0, h), r.uniform(0.006, 0.02) * w
        d.ellipse([x - rad, y - rad, x + rad, y + rad], outline=(255, 255, 255, 120), width=max(2, int(rad * 0.18)))

def save(img, path, size):
    img.resize(size, Image.LANCZOS).save(path)
    print("wrote", path, size)

def icon(size, rounded=True, fish_scale=0.30, bg=True):
    W = size * SS
    base = gradient(W, W, (79, 209, 245), (15, 95, 154)).convert("RGBA") if bg else Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(base, "RGBA")
    if bg:
        bubbles(d, W, W, 14)
    draw_fish(d, W * 0.60, W * 0.5, W * fish_scale)
    return base

# 1) launcher icon 192 (legacy)
img = icon(192)
mask = Image.new("L", img.size, 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=img.size[0] // 5, fill=255)
img.putalpha(mask)
save(img, "assets/icon_192.png", (192, 192))

# 2) adaptive icon: background + foreground (fish kept inside the central safe zone)
save(gradient(432 * SS, 432 * SS, (79, 209, 245), (15, 95, 154)).convert("RGBA"), "assets/icon_bg_432.png", (432, 432))
save(icon(432, bg=False, fish_scale=0.22), "assets/icon_fg_432.png", (432, 432))

# 3) Play Store icon 512x512 (full square; Google applies the rounding)
img = icon(512)
save(img, "store/play_icon_512.png", (512, 512))

# 4) Feature graphic 1024x500
W, H = 1024 * SS, 500 * SS
fg = gradient(W, H, (79, 209, 245), (10, 70, 125)).convert("RGBA")
d = ImageDraw.Draw(fg, "RGBA")
bubbles(d, W, H, 40, seed=7)
# small prey + big predator + player
draw_fish(d, W * 0.14, H * 0.72, H * 0.07, body=(180, 240, 120), belly=(235, 255, 200), fin=(90, 160, 50))
draw_fish(d, W * 0.22, H * 0.25, H * 0.06, body=(255, 140, 200), belly=(255, 214, 236), fin=(214, 72, 154))
draw_fish(d, W * 0.86, H * 0.64, H * 0.19, body=(120, 40, 60), belly=(190, 110, 125), fin=(70, 20, 35))
draw_fish(d, W * 0.60, H * 0.28, H * 0.12, crown=True)
f1 = ImageFont.truetype(FONT, int(H * 0.15))
f2 = ImageFont.truetype(FONT, int(H * 0.085))
def text_outline(x, y, t, font, fill):
    for dx in range(-6, 7, 3):
        for dy in range(-6, 7, 3):
            d.text((x + dx, y + dy), t, font=font, fill=(8, 50, 90), anchor="mm")
    d.text((x, y), t, font=font, fill=fill, anchor="mm")
text_outline(W * 0.38, H * 0.58, "Fish Evolution", f1, (255, 214, 58))
text_outline(W * 0.38, H * 0.78, "OCEAN RUN", f2, (255, 255, 255))
save(fg.convert("RGB"), "store/feature_graphic_1024x500.png", (1024, 500))
