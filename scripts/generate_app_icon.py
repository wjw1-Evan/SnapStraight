#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw

# Colors (hex to RGB)
BLUE_TOP = (14, 165, 233)   # #0ea5e9
BLUE_BOTTOM = (59, 130, 246)  # #3b82f6
WHITE = (255, 255, 255)
BLUE_DARK = (23, 78, 166)


def generate_icon(size: int, include_background: bool = True) -> Image.Image:
    """Generate icon image.

    Args:
        size: Output square size.
        include_background: Whether to paint gradient rounded background.
    """
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if include_background:
        radius = int(size * 0.2)
        # Gradient background
        for y in range(size):
            t = y / (size - 1)
            r = int(BLUE_TOP[0] * (1 - t) + BLUE_BOTTOM[0] * t)
            g = int(BLUE_TOP[1] * (1 - t) + BLUE_BOTTOM[1] * t)
            b = int(BLUE_TOP[2] * (1 - t) + BLUE_BOTTOM[2] * t)
            draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle([(0, 0), (size, size)], radius, fill=255)
        img.putalpha(mask)

    # Document rectangle (centered)
    doc_w, doc_h = int(size * 0.7), int(size * 0.84)
    doc_r = int(size * 0.06)
    cx, cy = size // 2, size // 2
    left = cx - doc_w // 2
    top = cy - doc_h // 2
    right = cx + doc_w // 2
    bottom = cy + doc_h // 2

    # Subtle drop shadow
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(shadow)
    sh_draw.rounded_rectangle(
        [(left + int(size * 0.006), top + int(size * 0.01)),
         (right + int(size * 0.006), bottom + int(size * 0.01))],
        doc_r,
        fill=(0, 0, 0, 60),
    )
    img = Image.alpha_composite(img, shadow)

    # Draw document
    doc = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    doc_draw = ImageDraw.Draw(doc)
    doc_draw.rounded_rectangle([(left, top), (right, bottom)], doc_r, fill=WHITE)

    # Guide lines (L-shaped corners)
    L = int(size * 0.12)
    T = int(size * 0.02)

    # Top-left
    doc_draw.line([(left, top), (left + L, top)], fill=BLUE_DARK, width=T)
    doc_draw.line([(left, top), (left, top + L)], fill=BLUE_DARK, width=T)
    # Top-right
    doc_draw.line([(right, top), (right - L, top)], fill=BLUE_DARK, width=T)
    doc_draw.line([(right, top), (right, top + L)], fill=BLUE_DARK, width=T)
    # Bottom-left
    doc_draw.line([(left, bottom), (left + L, bottom)], fill=BLUE_DARK, width=T)
    doc_draw.line([(left, bottom), (left, bottom - L)], fill=BLUE_DARK, width=T)
    # Bottom-right
    doc_draw.line([(right, bottom), (right - L, bottom)], fill=BLUE_DARK, width=T)
    doc_draw.line([(right, bottom), (right, bottom - L)], fill=BLUE_DARK, width=T)

    return Image.alpha_composite(img, doc)


def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def main():
    # iOS icons with background
    ios_dir = 'ios/SnapStraight/Assets.xcassets/AppIcon.appiconset'
    ensure_dir(ios_dir)
    base_ios = generate_icon(1024, include_background=True)
    # 为了符合 App Store 要求：iOS 大图标不可包含透明或 Alpha 通道
    # 这里将图标统一转换为 RGB，无 Alpha 通道
    base_ios = base_ios.convert('RGB')
    base_ios.save(f"{ios_dir}/AppIcon-1024.png", 'PNG')
    print('Saved:', f"{ios_dir}/AppIcon-1024.png")

    ios_sizes = {
        'AppIcon-20@1x.png': 20,
        'AppIcon-20@1x~ipad.png': 20,
        'AppIcon-20@2x.png': 40,
        'AppIcon-20@2x~ipad.png': 40,
        'AppIcon-20@3x.png': 60,
        'AppIcon-29@1x.png': 29,
        'AppIcon-29@2x.png': 58,
        'AppIcon-29@3x.png': 87,
        'AppIcon-40@1x.png': 40,
        'AppIcon-40@1x~ipad.png': 40,
        'AppIcon-40@2x.png': 80,
        'AppIcon-40@2x~ipad.png': 80,
        'AppIcon-40@3x.png': 120,
        'AppIcon-60@2x.png': 120,
        'AppIcon-60@3x.png': 180,
        'AppIcon-76@1x.png': 76,
        'AppIcon-76@2x.png': 152,
        'AppIcon-83.5@2x.png': 167,
    }

    for name, sz in ios_sizes.items():
        resized = base_ios.resize((sz, sz), Image.LANCZOS).convert('RGB')
        out = f"{ios_dir}/{name}"
        resized.save(out, 'PNG')
        print('Saved:', out)

    # Android adaptive icon foreground (transparent background)
    android_foreground_base = generate_icon(432, include_background=False)
    # Android legacy fallback full icon (background + foreground)
    android_full_base = generate_icon(432, include_background=True)

    mipmap_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }

    def make_round(img: Image.Image) -> Image.Image:
        """Apply circular mask to produce round icon."""
        size = img.size[0]
        mask = Image.new('L', img.size, 0)
        mdraw = ImageDraw.Draw(mask)
        mdraw.ellipse([(0, 0), (size, size)], fill=255)
        rounded = Image.new('RGBA', img.size, (0, 0, 0, 0))
        rounded.paste(img, (0, 0), mask)
        return rounded

    for folder, sz in mipmap_sizes.items():
        outdir = f"android/app/src/main/res/{folder}"
        ensure_dir(outdir)
        # Adaptive foreground PNG
        out_fg = f"{outdir}/ic_launcher_foreground.png"
        android_foreground_base.resize((sz, sz), Image.LANCZOS).save(out_fg, 'PNG')
        print('Saved:', out_fg)
        # Legacy square fallback PNG
        out_legacy = f"{outdir}/ic_launcher.png"
        android_full_base.resize((sz, sz), Image.LANCZOS).save(out_legacy, 'PNG')
        print('Saved:', out_legacy)
        # Legacy round fallback PNG (API 25 uses roundIcon if provided)
        out_round = f"{outdir}/ic_launcher_round.png"
        make_round(android_full_base.resize((sz, sz), Image.LANCZOS)).save(out_round, 'PNG')
        print('Saved:', out_round)


if __name__ == '__main__':
    main()
