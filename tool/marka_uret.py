#!/usr/bin/env python3
"""Rebelz Media marka varlıklarını üretir.

Kaynak: assets/brand/rebelz-logo.jpg (1024x1024, siyah zemin üzerinde
kırmızı fırça "R" + beyaz "REBELZ").

Üretilenler:
  assets/brand/rebelz-mark.png        kırmızı R (saydam zemin)
  assets/brand/rebelz-wordmark.png    REBELZ yazısı (saydam zemin)
  android/app/src/main/res/mipmap-*/  launcher ikonları (siyah zemin + R)
  android/app/src/main/res/mipmap-anydpi-v26/  adaptive icon XML

Kullanım:  python3 tool/marka_uret.py
Gereksinim: pillow  (pip install pillow)
"""

from __future__ import annotations

import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/brand/rebelz-logo.jpg')
BRAND = os.path.join(ROOT, 'assets/brand')
RES = os.path.join(ROOT, 'android/app/src/main/res')

# Kaynak görselde ölçülen sınırlar
MARK_BOX = (112, 391, 384, 708)      # kırmızı R
LOGO_BOX = (112, 341, 905, 708)      # R + REBELZ

BLACK = (0, 0, 0, 255)

LAUNCHER = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

FOREGROUND = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
}


def cut(box, alpha_from_luma: bool = True) -> Image.Image:
    """Kaynak JPEG'den kırpıp siyah zemini saydam yapar."""
    image = Image.open(SRC).convert('RGB').crop(box)
    out = Image.new('RGBA', image.size, (0, 0, 0, 0))
    src = image.load()
    dst = out.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b = src[x, y]
            if alpha_from_luma:
                # Siyah zemin → saydam; parlaklık alfa olur.
                alpha = max(r, g, b)
                if alpha < 26:
                    continue
                # Alfa ile birlikte rengi normalize et (siyahla karışmayı azalt)
                scale = 255.0 / alpha
                dst[x, y] = (
                    min(255, int(r * scale)),
                    min(255, int(g * scale)),
                    min(255, int(b * scale)),
                    min(255, int(alpha * 1.15)),
                )
            else:
                dst[x, y] = (r, g, b, 255)
    return out


def cut_mark(box: tuple[int, int, int, int]) -> Image.Image:
    """Yalnızca kırmızı fırça izlerini alır (beyaz yazı artefaktları atılır)."""
    image = Image.open(SRC).convert('RGB').crop(box)
    out = Image.new('RGBA', image.size, (0, 0, 0, 0))
    src = image.load()
    dst = out.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b = src[x, y]
            other = max(g, b)
            if r < 60 or r - other < 35:
                continue  # kırmızı değil (siyah zemin veya beyaz yazı)
            alpha = min(255, int((r - other) * 2.4))
            scale = 255.0 / max(1, max(r, g, b))
            dst[x, y] = (
                min(255, int(r * scale)),
                min(255, int(g * scale)),
                min(255, int(b * scale)),
                alpha,
            )
    box_trim = out.getbbox()
    return out.crop(box_trim) if box_trim else out


def fit(image: Image.Image, size: int, ratio: float) -> Image.Image:
    """Görseli `size` kutusuna, en uzun kenarı `ratio*size` olacak şekilde sığdırır."""
    target = int(size * ratio)
    w, h = image.size
    scale = target / max(w, h)
    new = (max(1, int(w * scale)), max(1, int(h * scale)))
    return image.resize(new, Image.LANCZOS)


def on_black(image: Image.Image, size: int, ratio: float, radius_ratio: float = 0.0) -> Image.Image:
    canvas = Image.new('RGBA', (size, size), BLACK)
    art = fit(image, size, ratio)
    x = (size - art.size[0]) // 2
    y = (size - art.size[1]) // 2
    canvas.alpha_composite(art, (x, y))
    if radius_ratio > 0:
        # Yuvarlatılmış köşe maskesi (launcher ikonları için)
        mask = Image.new('L', (size, size), 0)
        from PIL import ImageDraw

        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size - 1, size - 1],
            radius=int(size * radius_ratio),
            fill=255,
        )
        canvas.putalpha(mask)
    return canvas


def save(image: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, 'PNG', optimize=True)


def main() -> None:
    mark = cut_mark(MARK_BOX)
    wordmark = cut(LOGO_BOX)

    # Uygulama içi varlıklar (2x/3x için büyük tutulur)
    save(mark, os.path.join(BRAND, 'rebelz-mark.png'))
    save(wordmark, os.path.join(BRAND, 'rebelz-wordmark.png'))
    save(fit(mark, 512, 1.0), os.path.join(BRAND, 'rebelz-mark-512.png'))

    # Klasik launcher ikonları
    for density, size in LAUNCHER.items():
        icon = on_black(mark, size, 0.66, radius_ratio=0.22)
        save(icon, os.path.join(RES, f'mipmap-{density}/ic_launcher.png'))
        save(icon, os.path.join(RES, f'mipmap-{density}/ic_launcher_round.png'))

    # Adaptive icon katmanı (arka plan: siyah, ön plan: R)
    for density, size in FOREGROUND.items():
        fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        art = fit(mark, size, 0.46)
        fg.alpha_composite(art, ((size - art.size[0]) // 2, (size - art.size[1]) // 2))
        save(fg, os.path.join(RES, f'mipmap-{density}/ic_launcher_foreground.png'))

    adaptive = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(adaptive, exist_ok=True)
    xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with open(os.path.join(adaptive, name), 'w', encoding='utf-8') as handle:
            handle.write(xml)

    colors = os.path.join(RES, 'values/colors.xml')
    os.makedirs(os.path.dirname(colors), exist_ok=True)
    if not os.path.exists(colors):
        with open(colors, 'w', encoding='utf-8') as handle:
            handle.write(
                '<?xml version="1.0" encoding="utf-8"?>\n'
                '<resources>\n'
                '    <color name="ic_launcher_background">#000000</color>\n'
                '</resources>\n'
            )

    print('Marka varlıkları üretildi.')


if __name__ == '__main__':
    main()
