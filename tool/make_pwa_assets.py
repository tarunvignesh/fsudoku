"""Generates the iOS startup images an installed web app needs.

iOS shows a blank screen between tapping a home-screen icon and the page
painting, unless an `apple-touch-startup-image` exists for that exact device
size. These are drawn to match the boot screen in web/index.html, so the
hand-off from splash to page is invisible.

Run with a Python that has Pillow:

    python tool/make_pwa_assets.py
"""

import pathlib

from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parent.parent / 'web' / 'splash'

# Matches :root in web/index.html.
DARK_BG = (14, 17, 22)
DARK_CELL = (255, 255, 255, 36)
LIGHT_BG = (244, 246, 250)
LIGHT_CELL = (28, 32, 51, 41)

# Device pixel sizes iOS matches exactly, with the media query it needs.
# width, height, dpr -- portrait only; iOS falls back to background_color for
# anything not listed, which is why the colours above have to agree.
DEVICES = [
    (750, 1334, 2),    # iPhone SE, 8
    (828, 1792, 2),    # iPhone XR, 11
    (1125, 2436, 3),   # iPhone X, XS, 11 Pro
    (1170, 2532, 3),   # iPhone 12, 13, 14
    (1290, 2796, 3),   # iPhone 14 Pro Max, 15 Plus
    (1536, 2048, 2),   # iPad 9.7
    (1668, 2388, 2),   # iPad Pro 11
    (2048, 2732, 2),   # iPad Pro 12.9
]


def draw_splash(w: int, h: int, dark: bool) -> Image.Image:
    """A 3x3 grid motif centred on the app's background colour."""
    bg = DARK_BG if dark else LIGHT_BG
    cell = DARK_CELL if dark else LIGHT_CELL

    img = Image.new('RGB', (w, h), bg)
    overlay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # Scale the motif to the short edge so it looks the same on every device.
    unit = min(w, h) // 11
    gap = max(2, unit // 7)
    total = unit * 3 + gap * 2
    x0 = (w - total) // 2
    y0 = (h - total) // 2

    for row in range(3):
        for col in range(3):
            x = x0 + col * (unit + gap)
            y = y0 + row * (unit + gap)
            d.rounded_rectangle(
                [x, y, x + unit, y + unit],
                radius=unit // 6,
                fill=cell,
            )

    return Image.alpha_composite(img.convert('RGBA'), overlay).convert('RGB')


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    links = []

    for w, h, dpr in DEVICES:
        for dark in (True, False):
            scheme = 'dark' if dark else 'light'
            name = f'splash-{w}x{h}-{scheme}.png'
            path = OUT / name
            draw_splash(w, h, dark).save(path, optimize=True)
            total += path.stat().st_size
            links.append(
                f'  <link rel="apple-touch-startup-image" '
                f'href="splash/{name}"\n'
                f'        media="(prefers-color-scheme: {scheme}) and '
                f'(device-width: {w // dpr}px) and '
                f'(device-height: {h // dpr}px) and '
                f'(-webkit-device-pixel-ratio: {dpr}) and '
                f'(orientation: portrait)">'
            )

    print(f'{len(DEVICES) * 2} splash images, {total / 1024:,.0f} KB total')
    print('\n'.join(links))


if __name__ == '__main__':
    main()
