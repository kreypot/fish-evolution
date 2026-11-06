"""Adds a short caption banner to each real screenshot (allowed by Google Play, and it helps conversions).
Usage: python3 tools/caption_screenshots.py <input_dir> <output_dir>      (needs: pip install pillow)"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
CAPTIONS = {
    "01_eat_to_grow": "Eat smaller fish to grow!",
    "02_escape_predators": "Escape the hungry predators",
    "03_customize_fish": "Customize your fish",
    "04_volcano_world": "10 amazing underwater worlds",
    "05_300_levels": "300 levels to conquer",
    "06_neon_abyss": "Evolve into the biggest fish",
    "07_start_small": "Start small. Think big.",
    "08_level_complete": "Collect coins, unlock new looks",
    "09_main_menu": "Free offline fish game. No ads!",
    "10_checkpoints": "Checkpoints keep you going",
}

def caption(path_in, path_out, text):
    img = Image.open(path_in).convert("RGBA")
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    size = max(28, int(h * 0.065))
    font = ImageFont.truetype(FONT, size)
    tw = d.textlength(text, font=font)
    pad = int(size * 0.55)
    bw, bh = tw + pad * 2, size + pad * 1.3
    x0, y0 = (w - bw) / 2, h - bh - h * 0.04
    d.rounded_rectangle([x0, y0, x0 + bw, y0 + bh], radius=bh / 2, fill=(6, 40, 70, 205))
    d.text((w / 2, y0 + bh / 2), text, font=font, fill=(255, 214, 58, 255), anchor="mm")
    Image.alpha_composite(img, layer).convert("RGB").save(path_out)

def main(src, dst):
    n = 0
    for root, _, files in os.walk(src):
        for f in sorted(files):
            if not f.endswith(".png"):
                continue
            key = f[:-4]
            rel = os.path.relpath(root, src)
            out_dir = os.path.join(dst, rel)
            os.makedirs(out_dir, exist_ok=True)
            caption(os.path.join(root, f), os.path.join(out_dir, f), CAPTIONS.get(key, ""))
            n += 1
    print("captioned", n, "screenshots ->", dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
