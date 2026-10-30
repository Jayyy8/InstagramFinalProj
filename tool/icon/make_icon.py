"""Draws the app icon (a sunset-gradient tile with a white camera) and writes
every Android and iPhone size.

    pip install pillow
    python tool/icon/make_icon.py

Android: legacy icons (rounded square) plus an adaptive icon (gradient
background + camera foreground) for Android 8 and newer. iPhone: square,
opaque icons (iOS rounds the corners itself).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

S = 1024  # master size

# Sunset gradient: yellow (bottom left) → orange → pink → purple → blue (top).
STOPS = [
    (0.00, (254, 218, 117)),
    (0.22, (250, 126, 30)),
    (0.50, (214, 41, 118)),
    (0.78, (150, 47, 191)),
    (1.00, (79, 91, 213)),
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def color_at(t):
    t = max(0.0, min(1.0, t))
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        if t <= t1:
            return lerp(c0, c1, (t - t0) / (t1 - t0))
    return STOPS[-1][1]


def gradient(size):
    """Radial glow from the bottom-left corner, like a sunset."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy = size * 0.18, size * 1.05
    far = math.hypot(size, size) * 0.95
    for y in range(size):
        for x in range(size):
            px[x, y] = color_at(math.hypot(x - cx, y - cy) / far)
    return img


def camera(size, scale=1.0):
    """White camera on transparent: body with a viewfinder bump, a lens
    ring and a small flash light. [scale] shrinks it for the adaptive
    icon's safe zone."""
    big = size * 4  # draw large, then shrink for smooth edges
    layer = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(layer)
    c = big / 2
    w = big * 0.62 * scale
    h = big * 0.46 * scale
    top = c - h / 2 + big * 0.03 * scale
    r = big * 0.10 * scale
    # Viewfinder bump on top of the body.
    bw, bh = w * 0.34, h * 0.22
    d.rounded_rectangle(
        [c - bw / 2, top - bh * 0.8, c + bw / 2, top + bh * 0.4],
        radius=bh * 0.45,
        fill=255,
    )
    # Body.
    d.rounded_rectangle([c - w / 2, top, c + w / 2, top + h], radius=r, fill=255)
    # Lens: cut a ring out of the body, then a solid center.
    lens_c = (c, top + h * 0.53)
    ro, ri, rc = h * 0.36, h * 0.27, h * 0.15
    d.ellipse([lens_c[0] - ro, lens_c[1] - ro, lens_c[0] + ro, lens_c[1] + ro], fill=0)
    d.ellipse([lens_c[0] - ri, lens_c[1] - ri, lens_c[0] + ri, lens_c[1] + ri], fill=255)
    d.ellipse([lens_c[0] - rc, lens_c[1] - rc, lens_c[0] + rc, lens_c[1] + rc], fill=0)
    # Flash light, top right of the body.
    fx, fy, fr = c + w * 0.33, top + h * 0.2, h * 0.07
    d.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=0)
    mask = layer.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(mask)
    return out


def rounded_mask(size, radius_frac=0.225):
    big = size * 4
    m = Image.new("L", (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, big - 1, big - 1], radius=big * radius_frac, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def with_shadow(glyph):
    """A soft shadow under the camera so it reads on light parts."""
    shadow = Image.new("RGBA", glyph.size, (0, 0, 0, 0))
    a = glyph.getchannel("A").filter(ImageFilter.GaussianBlur(glyph.size[0] * 0.012))
    shadow.putalpha(a.point(lambda v: int(v * 0.18)))
    out = Image.new("RGBA", glyph.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, int(glyph.size[0] * 0.008)))
    out.alpha_composite(glyph)
    return out


print("drawing…")
bg = gradient(S)
glyph = with_shadow(camera(S))
square = bg.convert("RGBA")
square.alpha_composite(glyph)

# ───── iPhone: square and opaque ─────
os.makedirs(IOS, exist_ok=True)
ios_sizes = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
}
flat = square.convert("RGB")
for name, px in ios_sizes.items():
    flat.resize((px, px), Image.LANCZOS).save(os.path.join(IOS, name))

# ───── Android legacy: rounded square on transparent ─────
legacy = square.copy()
legacy.putalpha(rounded_mask(S))
densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for dens, k in densities.items():
    folder = os.path.join(RES, f"mipmap-{dens}")
    os.makedirs(folder, exist_ok=True)
    legacy.resize((round(48 * k), round(48 * k)), Image.LANCZOS).save(os.path.join(folder, "ic_launcher.png"))
    # Adaptive icon layers: 108dp, camera inside the 66dp safe zone.
    n = round(108 * k)
    gradient_layer = bg.resize((n, n), Image.LANCZOS)
    gradient_layer.save(os.path.join(folder, "ic_launcher_background.png"))
    camera(n, scale=0.66).save(os.path.join(folder, "ic_launcher_foreground.png"))

anydpi = os.path.join(RES, "mipmap-anydpi-v26")
os.makedirs(anydpi, exist_ok=True)
open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8").write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    "</adaptive-icon>\n"
)
print("done")
