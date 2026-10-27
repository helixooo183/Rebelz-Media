#!/usr/bin/env python3
"""docs/ekranlar/*.png dosyalarından docs/screens.png kontak sayfası üretir.

Kullanım:
    python3 tool/ekran_montaj.py

Bağımlılık: pillow  (pip install pillow)

Düzen: her satırda en fazla 6 görsel; görseller 300 px genişliğe küçültülür,
koyu zemin + ince çerçeve + numara etiketiyle yerleştirilir. Çıktı
docs/screens.png (repoda README'de gösterilir).
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("pillow gerekli: pip install pillow")

KOK = Path(__file__).resolve().parent.parent
EKRANLAR = KOK / "docs" / "ekranlar"
CIKTI = KOK / "docs" / "screens.png"

GENISLIK = 300
SUTUN = 6
BOSLUK = 18
ARKA = (9, 9, 11)
CERCEVE = (44, 44, 52)
YAZI = (160, 160, 170)


def etiket(path: Path) -> str:
    """01_splash.png -> 01 splash"""
    return path.stem.replace("_", " ")


def font(boyut: int) -> ImageFont.ImageFont:
    for aday in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ):
        if Path(aday).exists():
            return ImageFont.truetype(aday, boyut)
    return ImageFont.load_default()


def main() -> None:
    dosyalar = sorted(EKRANLAR.glob("*.png"))
    if not dosyalar:
        sys.exit(f"Görsel bulunamadı: {EKRANLAR}")

    ornek = Image.open(dosyalar[0])
    yukseklik = round(GENISLIK * ornek.height / ornek.width)

    satir = (len(dosyalar) + SUTUN - 1) // SUTUN
    etiket_yuksekligi = 26
    genislik = SUTUN * GENISLIK + (SUTUN + 1) * BOSLUK
    toplam = satir * (yukseklik + etiket_yuksekligi) + (satir + 1) * BOSLUK

    tuval = Image.new("RGB", (genislik, toplam), ARKA)
    kalem = ImageDraw.Draw(tuval)
    kucuk = font(15)

    for i, dosya in enumerate(dosyalar):
        sutun = i % SUTUN
        satir_no = i // SUTUN
        x = BOSLUK + sutun * (GENISLIK + BOSLUK)
        y = BOSLUK + satir_no * (yukseklik + etiket_yuksekligi + BOSLUK)

        resim = Image.open(dosya).convert("RGB")
        resim = resim.resize((GENISLIK, yukseklik), Image.LANCZOS)
        tuval.paste(resim, (x, y))
        kalem.rectangle(
            [x - 1, y - 1, x + GENISLIK, y + yukseklik],
            outline=CERCEVE,
        )
        kalem.text((x, y + yukseklik + 6), etiket(dosya), fill=YAZI, font=kucuk)

    CIKTI.parent.mkdir(parents=True, exist_ok=True)
    tuval.save(CIKTI, optimize=True)
    print(f"{CIKTI} yazıldı ({len(dosyalar)} ekran, {genislik}x{toplam})")


if __name__ == "__main__":
    main()
