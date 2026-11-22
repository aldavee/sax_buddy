#!/usr/bin/env python3
"""Generates high-DPI anti-aliased launcher icons for Sax Buddy."""

from pathlib import Path
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
RES_DIR = REPO_ROOT / "android" / "app" / "src" / "main" / "res"
ASSETS_ICON_DIR = REPO_ROOT / "assets" / "icon"
WINDOWS_ICO_PATH = REPO_ROOT / "windows" / "runner" / "resources" / "app_icon.ico"


def _lerp_color(c1, c2, t: float):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def render_background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (12, 16, 33, 255))
    px = img.load()
    c_top = (12, 16, 33, 255)      # Midnight jazz club stage
    c_mid = (28, 25, 64, 255)      # Deep indigo-velvet
    c_bot = (120, 53, 15, 255)     # Warm bronze spotlight
    for y in range(size):
        for x in range(size):
            t = (x + y) / max(1, (2 * size - 2))
            if t < 0.58:
                col = _lerp_color(c_top, c_mid, t / 0.58)
            else:
                col = _lerp_color(c_mid, c_bot, (t - 0.58) / 0.42)
            px[x, y] = col

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    pad = int(size * 0.14)
    gdraw.ellipse(
        [pad, pad, size - pad, size - pad],
        fill=(251, 191, 36, 38),  # Golden brass spotlight glow
    )
    return Image.alpha_composite(img, glow)


def render_foreground(size: int, full_bleed: bool = False) -> Image.Image:
    ss = 4
    canvas_sz = size * ss
    img = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = 1.22 if full_bleed else 1.0

    def pt(v: float) -> float:
        centered = (v - 54.0) * scale + 54.0
        return centered * (canvas_sz / 108.0)

    brass_light = (253, 224, 71, 255)
    brass_gold = (245, 158, 11, 255)
    brass_deep = (180, 83, 9, 255)
    pearl = (254, 249, 239, 255)
    ebony = (15, 23, 42, 255)

    # Neck & mouthpiece (top-left curving right into body tube)
    neck_w = max(4, int(5.5 * scale * (canvas_sz / 108.0)))
    body_w = max(6, int(9.0 * scale * (canvas_sz / 108.0)))
    bow_w = max(8, int(11.5 * scale * (canvas_sz / 108.0)))

    # Mouthpiece ebonite tip
    mp0 = (pt(26), pt(25))
    mp1 = (pt(36), pt(22))
    draw.line([mp0, mp1], fill=ebony, width=neck_w)
    # Neck gooseneck curve
    n1 = (pt(45), pt(23))
    n2 = (pt(47), pt(32))
    draw.line([mp1, n1, n2], fill=brass_light, width=neck_w, joint="curve")

    # Main saxophone body tube (slight diagonal down to bottom bow)
    b_top = (pt(47), pt(32))
    b_bot = (pt(45), pt(73))
    draw.line([b_top, b_bot], fill=brass_gold, width=body_w)

    # Bottom bow curve & upward bell tube
    bow_mid = (pt(54), pt(84))
    bell_mid = (pt(67), pt(76))
    bell_top = (pt(71), pt(54))
    draw.line(
        [b_bot, bow_mid, bell_mid, bell_top],
        fill=brass_gold,
        width=bow_w,
        joint="curve",
    )

    # Flared Saxophone Bell rim (ellipse at bell_top)
    bx0, by0, bx1, by1 = pt(59), pt(45), pt(83), pt(59)
    draw.ellipse(
        [bx0, by0, bx1, by1],
        fill=brass_light,
        outline=brass_deep,
        width=max(2, int(2.5 * scale * (canvas_sz / 108.0))),
    )
    # Dark inner bell throat
    ix0, iy0, ix1, iy1 = pt(63), pt(48), pt(79), pt(56)
    draw.ellipse([ix0, iy0, ix1, iy1], fill=(30, 20, 10, 235))

    # Mother-of-pearl key touches along the main stack
    pr = 2.6 * scale * (canvas_sz / 108.0)
    for ky in (39.0, 46.5, 54.0, 61.5, 68.5):
        kx = pt(46.0)
        py = pt(ky)
        draw.ellipse(
            [kx - pr, py - pr, kx + pr, py + pr],
            fill=pearl,
            outline=brass_deep,
            width=max(1, int(1.0 * scale * (canvas_sz / 108.0))),
        )

    # Musical eighth-note / sound wave badge floating above the bell
    nx, ny = pt(74.0), pt(30.0)
    nr = 4.2 * scale * (canvas_sz / 108.0)
    draw.ellipse([nx - nr, ny - nr * 0.8, nx + nr, ny + nr * 0.8], fill=brass_light)
    stem_w = max(2, int(2.4 * scale * (canvas_sz / 108.0)))
    stem_top = (nx + nr * 0.85, pt(18.0))
    draw.line([(nx + nr * 0.85, ny), stem_top], fill=brass_light, width=stem_w)
    draw.line([stem_top, (pt(83.0), pt(22.5))], fill=brass_light, width=stem_w)

    return img.resize((size, size), Image.Resampling.LANCZOS)


def render_combined_icon(size: int, circular: bool = False) -> Image.Image:
    bg = render_background(size)
    fg = render_foreground(size, full_bleed=True)
    merged = Image.alpha_composite(bg, fg)

    mask = Image.new("L", (size * 4, size * 4), 0)
    mdraw = ImageDraw.Draw(mask)
    if circular:
        pad = int(size * 4 * 0.02)
        mdraw.ellipse([pad, pad, size * 4 - pad, size * 4 - pad], fill=255)
    else:
        pad = int(size * 4 * 0.04)
        rad = int(size * 4 * 0.22)
        mdraw.rounded_rectangle(
            [pad, pad, size * 4 - pad, size * 4 - pad],
            radius=rad,
            fill=255,
        )
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(merged, (0, 0), mask)
    return out


def main():
    ASSETS_ICON_DIR.mkdir(parents=True, exist_ok=True)
    master = render_combined_icon(1024, circular=False)
    master.save(ASSETS_ICON_DIR / "app_icon.png", "PNG")

    WINDOWS_ICO_PATH.parent.mkdir(parents=True, exist_ok=True)
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(WINDOWS_ICO_PATH, format="ICO", sizes=ico_sizes)

    densities = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }

    for folder, (legacy_sz, fg_sz) in densities.items():
        target = RES_DIR / folder
        target.mkdir(parents=True, exist_ok=True)
        render_combined_icon(legacy_sz, circular=False).save(target / "ic_launcher.png", "PNG")
        render_combined_icon(legacy_sz, circular=True).save(target / "ic_launcher_round.png", "PNG")
        render_foreground(fg_sz, full_bleed=False).save(target / "ic_launcher_foreground.png", "PNG")

    print("Generated Sax Buddy launcher icons (Android mipmaps, assets/icon/app_icon.png, Windows app_icon.ico).")


if __name__ == "__main__":
    main()
