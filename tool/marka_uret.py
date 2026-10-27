#!/usr/bin/env python3
"""Rebelz Media marka görsellerini üretir (fırça logolu yeni kimlik).

Kaynak dosyalar (repoya girmeden, `kaynak/` klasöründe tutulur):
    kaynak/rebelz-banner.jpg    geniş REBELZ fırça banner'ı (2960x832)
    kaynak/google-g.png         Google "G" logosu (saydam zemin)

Üretilenler:
    assets/brand/rebelz-brush.png     kırmızı R + beyaz EBELZ, saydam zemin
    assets/brand/rebelz-mark.png      yalnızca kırmızı fırça R (uygulama ikonu vb.)
    assets/brand/rebelz-wordmark.png  yalnızca beyaz EBELZ yazısı
    assets/brand/banner.png           giriş ekranı üst bandı (grunge zemin)
    assets/brand/google-g.png         kırpılmış, ölçeklenmiş Google logosu
    assets/brand/buton-grunge.png     kırmızı grunge doku (buton zemini)
    android/app/src/main/res/mipmap-*/ic_launcher*.png   (mevcut boyutlar)

Kullanım:
    python3 tool/marka_uret.py

Bağımlılık: pillow, numpy
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

KOK = Path(__file__).resolve().parent.parent
KAYNAK = KOK / "kaynak"
MARKA = KOK / "assets" / "brand"

BANNER = KAYNAK / "rebelz-banner.jpg"
GOOGLE = KAYNAK / "google-g.png"

# Logo geometrisi (kaynak banner 2960x832 üzerinde ölçüldü)
RED_BOX = (608, 148, 1160, 780)
WHITE_BOX = (1060, 196, 2312, 608)


# --------------------------------------------------------------------------- #
# Fırça logoyu zeminden ayırma
# --------------------------------------------------------------------------- #
def _channels(path: Path):
    import numpy as np

    image = Image.open(path).convert("RGB")
    arr = np.asarray(image).astype(np.int16)
    return image, arr


def cut_logo(path: Path, kind: str, pad: int = 12) -> Image.Image:
    """Fırça darbelerini zeminden ayırıp saydam PNG üretir.

    kind = "red"   → yalnızca kırmızı R
    kind = "white" → yalnızca beyaz EBELZ
    kind = "both"  → ikisi birden (kırmızı R + beyaz EBELZ)
    """
    import numpy as np

    _, arr = _channels(path)
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]

    # Kırmızı: kanal farkı yüksek ve parlak (grunge zeminin koyu kırmızı
    # lekeleri elenir).
    chroma = r - np.maximum(g, b)
    red_alpha = np.clip((chroma - 40) * 4.5, 0, 255)
    red_alpha = np.where(r < 70, 0, red_alpha)

    # Beyaz: üç kanal da parlak ve renk farkı düşük.
    low = np.minimum(np.minimum(r, g), b)
    spread = np.maximum(np.maximum(r, g), b) - low
    white_alpha = np.clip((low - 120) * 3.2, 0, 255)
    white_alpha = np.where(spread > 60, 0, white_alpha)

    if kind == "red":
        alpha = red_alpha
        solid = np.dstack([np.full_like(r, 232), np.full_like(r, 24), np.full_like(r, 20)])
    elif kind == "white":
        alpha = white_alpha
        solid = np.dstack([np.full_like(r, 248), np.full_like(r, 248), np.full_like(r, 248)])
    else:
        alpha = np.maximum(red_alpha, white_alpha)
        # Hangi piksel kırmızı, hangisi beyaz? İki maskenin baskınlığı belirler;
        # böylece "REBELZ" yazısı kırmızıya boyanmaz.
        is_red = red_alpha >= white_alpha
        solid = np.dstack(
            [
                np.where(is_red, 232, 248),
                np.where(is_red, 24, 248),
                np.where(is_red, 20, 248),
            ]
        )

    rgba = np.dstack([solid[:, :, 0], solid[:, :, 1], solid[:, :, 2], alpha])
    result = Image.fromarray(rgba.astype(np.uint8), "RGBA")

    x0, y0, x1, y1 = tight_bbox(result, threshold=110, min_frac=0.01)
    result = result.crop(
        (
            max(0, x0 - pad),
            max(0, y0 - pad),
            min(result.width, x1 + pad),
            min(result.height, y1 + pad),
        )
    )
    # Kenarları yumuşat: alfa kanalına hafif bulanıklık.
    blurred = result.split()[-1].filter(ImageFilter.GaussianBlur(0.6))
    result.putalpha(blurred)
    return result


def tight_bbox(image: Image.Image, threshold: int = 110, min_frac: float = 0.004):
    """Sıçrama/leke noktalarını yok sayan sıkı sınır kutusu.

    Düz `getbbox()` tek bir sıçrama damlası yüzünden logoyu küçültüyordu;
    burada satır/sütun yoğunluğuna bakılır.
    """
    import numpy as np

    alpha = np.asarray(image.split()[-1]).astype(np.uint8)
    mask = alpha > threshold
    cols = mask.sum(axis=0)
    rows = mask.sum(axis=1)
    if cols.max() == 0 or rows.max() == 0:
        return image.getbbox() or (0, 0, image.width, image.height)

    xs = np.where(cols > cols.max() * min_frac)[0]
    ys = np.where(rows > rows.max() * min_frac)[0]
    return int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1


# --------------------------------------------------------------------------- #
# Grunge buton dokusu
# --------------------------------------------------------------------------- #
def make_banner(size: tuple[int, int] = (1400, 760)) -> Image.Image:
    """Giriş ekranı üst bandı: koyu grunge zemin (logo ayrı katman).

    Kaynak banner'daki REBELZ yazısı bant içine gömülmesin diye zemin
    prosedürel üretilir: kömür siyahı taban, fırça izleri, siyah sıçramalar,
    altta hafif kırmızı ısı.
    """
    width, height = size
    rnd = random.Random(7013)

    # 1) Taban: dikey geçişli kömür siyahı.
    base = Image.new("RGB", size)
    px = base.load()
    top = (30, 30, 32)
    mid = (20, 20, 22)
    bottom = (9, 9, 10)
    for y in range(height):
        t = y / (height - 1)
        if t < 0.55:
            k = t / 0.55
            row = tuple(int(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        else:
            k = (t - 0.55) / 0.45
            row = tuple(int(mid[i] + (bottom[i] - mid[i]) * k) for i in range(3))
        for x in range(width):
            px[x, y] = row

    # 2) Gri fırça darbeleri (doku).
    strokes = Image.new("RGBA", size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(strokes)
    for _ in range(240):
        x0 = rnd.uniform(-100, width)
        y0 = rnd.uniform(-30, height)
        length = rnd.uniform(50, 460)
        tilt = rnd.uniform(-22, 22)
        value = rnd.randint(45, 125)
        sdraw.line(
            (x0, y0, x0 + length, y0 + tilt),
            fill=(value, value, value + rnd.randint(0, 8), rnd.randint(26, 96)),
            width=rnd.randint(1, 5),
        )
    strokes = strokes.filter(ImageFilter.GaussianBlur(1.0))
    base = Image.alpha_composite(base.convert("RGBA"), strokes)

    # 3) Sıçramalar.
    splatter = Image.new("RGBA", size, (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(splatter)
    for _ in range(1000):
        cx = rnd.uniform(-10, width + 10)
        cy = rnd.uniform(-10, height + 10)
        radius = rnd.choices(
            [rnd.uniform(0.5, 2.4), rnd.uniform(2.4, 7), rnd.uniform(7, 18)],
            weights=[76, 19, 5],
        )[0]
        pdraw.ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius),
            fill=(rnd.randint(6, 40), rnd.randint(6, 38), rnd.randint(7, 40),
                  rnd.randint(70, 210)),
        )
    base = Image.alpha_composite(base, splatter)

    # 4) Altta hafif kırmızı ısı (marka rengiyle bağ).
    heat = Image.new("RGBA", size, (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(heat)
    hdraw.ellipse(
        (width * 0.05, height * 0.55, width * 0.95, height * 1.6),
        fill=(150, 8, 24, 70),
    )
    heat = heat.filter(ImageFilter.GaussianBlur(90))
    base = Image.alpha_composite(base, heat)

    return base.convert("RGB")


def make_grunge(size: tuple[int, int] = (1200, 420)) -> Image.Image:
    """Kırmızı grunge doku — giriş ekranındaki ana butonun zemini.

    Referans görseldeki gibi **neredeyse düz** parlak kırmızı zemin; üzerinde
    ince çizikler, küçük siyah boya sıçramaları ve yer yer duman/sis lekeleri.
    Doku bilinçli olarak çok hafif tutulur: buton metni her boyutta okunur.
    """
    width, height = size
    rnd = random.Random(20261027)

    # 1) Zemin: hafif dikey geçişli düz kırmızı.
    base = Image.new("RGB", size)
    px = base.load()
    top = (228, 26, 42)
    bottom = (198, 14, 34)
    for y in range(height):
        t = y / (height - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(width):
            px[x, y] = row

    # 2) Yumuşak ışık: ortada hafif parlaklık (dokunun "boyanmış" hissi).
    glow = Image.new("L", size, 0)
    ImageDraw.Draw(glow).ellipse(
        (width * 0.08, -height * 0.6, width * 0.92, height * 1.1), fill=255
    )
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    lighter = Image.new("RGB", size, (245, 48, 58))
    base = Image.composite(lighter, base, glow.point(lambda v: int(v * 0.35)))

    # 3) Sis/duman lekeleri (çok hafif, geniş).
    haze = Image.new("RGBA", size, (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(haze)
    for _ in range(16):
        cx = rnd.uniform(0, width)
        cy = rnd.uniform(0, height)
        rx = rnd.uniform(60, 220)
        ry = rnd.uniform(20, 90)
        hdraw.ellipse(
            (cx - rx, cy - ry, cx + rx, cy + ry),
            fill=(rnd.randint(90, 150), 0, rnd.randint(10, 40), rnd.randint(10, 26)),
        )
    haze = haze.filter(ImageFilter.GaussianBlur(26))
    base = Image.alpha_composite(base.convert("RGBA"), haze)

    # 4) İnce çizikler.
    scratches = Image.new("RGBA", size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(scratches)
    for _ in range(38):
        x0 = rnd.uniform(-40, width)
        y0 = rnd.uniform(0, height)
        length = rnd.uniform(80, 460)
        tilt = rnd.uniform(-22, 22)
        sdraw.line(
            (x0, y0, x0 + length, y0 + tilt),
            fill=(rnd.randint(10, 60), 0, 0, rnd.randint(40, 110)),
            width=1 if rnd.random() < 0.75 else 2,
        )
    scratches = scratches.filter(ImageFilter.GaussianBlur(0.5))
    base = Image.alpha_composite(base, scratches)

    # 5) Sıçramalar: çoğu küçük, seyrek orta/büyük damlalar.
    splatter = Image.new("RGBA", size, (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(splatter)
    for _ in range(260):
        # Damlalar ağırlıklı olarak kenarlarda toplanır; ortada metin var.
        if rnd.random() < 0.62:
            cx = rnd.choice([rnd.uniform(-6, width * 0.18), rnd.uniform(width * 0.82, width + 6)])
        else:
            cx = rnd.uniform(-6, width + 6)
        cy = rnd.uniform(-6, height + 6)
        radius = rnd.choices(
            [rnd.uniform(0.4, 1.4), rnd.uniform(1.4, 3.6), rnd.uniform(3.6, 8)],
            weights=[84, 13, 3],
        )[0]
        pdraw.ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius),
            fill=(rnd.randint(0, 34), 0, rnd.randint(0, 14), rnd.randint(50, 140)),
        )
    base = Image.alpha_composite(base, splatter)

    # 6) Kenar karartması: metin ve köşe yuvarlaması daha net okunsun.
    vignette = Image.new("L", size, 0)
    ImageDraw.Draw(vignette).rectangle(
        (24, 18, width - 24, height - 18), fill=255
    )
    vignette = vignette.filter(ImageFilter.GaussianBlur(24))
    dark = Image.new("RGBA", size, (0, 0, 0, 120))
    out = Image.composite(base, Image.alpha_composite(base, dark), vignette)
    return out.convert("RGB")


# --------------------------------------------------------------------------- #
# Launcher ikonları
# --------------------------------------------------------------------------- #
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def make_launcher(mark: Image.Image) -> None:
    res = KOK / "android" / "app" / "src" / "main" / "res"
    # Sıçrama noktalarını atarak logoyu kareye daha büyük yerleştir.
    mark = mark.crop(tight_bbox(mark))

    for density, size in DENSITIES.items():
        folder = res / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)

        # Tam ikon: siyah zemin + ortada kırmızı R.
        icon = Image.new("RGBA", (size, size), (0, 0, 0, 255))
        inner = int(size * 0.80)
        mark_resized = mark.copy()
        mark_resized.thumbnail((inner, inner), Image.LANCZOS)
        icon.paste(
            mark_resized,
            ((size - mark_resized.width) // 2, (size - mark_resized.height) // 2),
            mark_resized,
        )
        icon.convert("RGB").save(folder / "ic_launcher.png")

        # Yuvarlak ikon: maske.
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        round_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        round_icon.paste(icon, (0, 0))
        round_icon.putalpha(mask)
        round_icon.save(folder / "ic_launcher_round.png")

        # Adaptive foreground: saydam zemin, ortada R (güvenli alan %66).
        fg_size = int(size * 1.5)
        fg = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
        inner_fg = int(fg_size * 0.46)
        fg_mark = mark.copy()
        fg_mark.thumbnail((inner_fg, inner_fg), Image.LANCZOS)
        fg.paste(
            fg_mark,
            ((fg_size - fg_mark.width) // 2, (fg_size - fg_mark.height) // 2),
            fg_mark,
        )
        fg.save(folder / "ic_launcher_foreground.png")


# --------------------------------------------------------------------------- #
def main() -> None:
    MARKA.mkdir(parents=True, exist_ok=True)
    if not BANNER.exists():
        raise SystemExit(f"Kaynak banner yok: {BANNER}")

    mark = cut_logo(BANNER, "red")
    wordmark = cut_logo(BANNER, "white")
    brush = cut_logo(BANNER, "both")

    mark.save(MARKA / "rebelz-mark.png")
    mark.resize((512, round(512 * mark.height / mark.width)), Image.LANCZOS).save(
        MARKA / "rebelz-mark-512.png"
    )
    wordmark.save(MARKA / "rebelz-wordmark.png")

    # Giriş ekranı bandı: koyu grunge zemin (logo ayrı asset).
    make_banner().save(MARKA / "banner.png", optimize=True)
    brush.save(MARKA / "rebelz-brush.png")

    if GOOGLE.exists():
        google = Image.open(GOOGLE).convert("RGBA")
        box = google.getbbox() or (0, 0, google.width, google.height)
        google = google.crop(box)
        side = max(google.width, google.height)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(
            google,
            ((side - google.width) // 2, (side - google.height) // 2),
            google,
        )
        canvas.resize((256, 256), Image.LANCZOS).save(MARKA / "google-g.png")

    make_grunge().save(MARKA / "buton-grunge.png", optimize=True)
    make_launcher(mark)

    for f in sorted(MARKA.glob("*.png")):
        with Image.open(f) as img:
            print(f"{f.relative_to(KOK)}  {img.width}x{img.height}")


if __name__ == "__main__":
    main()
