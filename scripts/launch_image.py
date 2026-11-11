#!/usr/bin/env python3
"""Hace la imagen de la pantalla de arranque (App/Assets.xcassets/LaunchImage.imageset) a partir de
una captura de la pantalla de Rutinas hecha en el iPhone: deja el título y la barra de pestañas tal
cual, borra la barra de estado (la pinta iOS encima) y la nube (su estado no se sabe al arrancar), y
cambia cada tarjeta por una igual con bandas grises en el sitio del nombre y de las dos líneas de
ejercicios. Así, al cargar, solo aparece el texto (decisión del usuario, 2026-11-11).

iOS no escala la imagen: la pone a su tamaño en puntos en el centro de la pantalla. Por eso la
captura tiene que ser del iPhone del usuario (un iPhone Air, 1260×2736) y hay que rehacerla si
cambia de iPhone o si cambian las barras o las tarjetas.

Uso: scripts/launch_image.py <captura.png> [<salida.png>]
Necesita Pillow; sin ella, en el NAS:
  docker run --rm -i -v "$PWD:/repo" -w /repo python:3.12-slim \
    sh -c 'pip -q install pillow && python scripts/launch_image.py captura.png'
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "App/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"

SCALE = 3                  # la captura va a @3x
STATUS_BAR = 70            # pt: la barra de estado, por encima del título
CLOUD = (330, 55, 420, 125)  # pt: la nube, a la derecha del título
CARD_RADIUS = 26           # pt: Theme.radius
BAND = (42, 44, 51)        # las bandas: un poco más claras que la tarjeta
# Las bandas, en pt desde la esquina de la tarjeta: (x, y, ancho, alto) del nombre y de las dos
# líneas de ejercicios, donde caen en la tarjeta de verdad. Largos distintos en cada tarjeta, para
# que no parezcan un patrón.
TEXT_X = 20
BANDS = [
    [(TEXT_X, 23, 113, 13), (TEXT_X, 45, 293, 9), (TEXT_X, 60, 187, 9)],
    [(TEXT_X, 23, 113, 13), (TEXT_X, 45, 300, 9), (TEXT_X, 60, 167, 9)],
    [(TEXT_X, 23, 113, 13), (TEXT_X, 45, 287, 9), (TEXT_X, 60, 173, 9)],
]


def px(value):
    return round(value * SCALE)


def differs(a, b, tolerance=6):
    return sum(abs(x - y) for x, y in zip(a, b)) > tolerance


def find_cards(image, background):
    """Las tarjetas, de arriba abajo: las franjas de otro color que el fondo en una columna que
    cruza las tarjetas sin pasar por el texto ni por el filete de color."""
    column = px(60)
    cards, start = [], None
    for y in range(px(STATUS_BAR), image.height // 2):
        inside = differs(image.getpixel((column, y)), background)
        if inside and start is None:
            start = y
        elif not inside and start is not None:
            if y - start > px(40):
                cards.append((start, y))
            start = None
    if not cards:
        sys.exit("No encuentro las tarjetas: ¿es una captura de Rutinas?")
    return cards


def card_edges(image, y, background):
    row = [image.getpixel((x, y)) for x in range(image.width)]
    inside = [x for x, colour in enumerate(row) if differs(colour, background)]
    return inside[0], inside[-1] + 1


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    image = Image.open(sys.argv[1]).convert("RGB")
    output = Path(sys.argv[2]) if len(sys.argv) == 3 else OUTPUT
    background = image.getpixel((5, image.height // 2))
    cards = find_cards(image, background)
    if len(cards) != len(BANDS):
        sys.exit(f"Hay {len(cards)} tarjetas y bandas para {len(BANDS)}: ajusta BANDS.")

    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, image.width, px(STATUS_BAR)), fill=background)
    draw.rectangle(tuple(px(v) for v in CLOUD), fill=background)
    for (top, bottom), bands in zip(cards, BANDS):
        left, right = card_edges(image, (top + bottom) // 2, background)
        card = image.getpixel((right - px(20), top + px(8)))
        draw.rectangle((left - 4, top - 4, right + 4, bottom + 4), fill=background)
        draw.rounded_rectangle((left, top, right - 1, bottom - 1), px(CARD_RADIUS), fill=card)
        for x, y, width, height in bands:
            x0, y0 = left + px(x), top + px(y)
            draw.rounded_rectangle((x0, y0, x0 + px(width), y0 + px(height)), px(height) / 2, fill=BAND)
    image.save(output, optimize=True)
    print(f"{output}: {image.width}×{image.height}, {len(cards)} tarjetas")


if __name__ == "__main__":
    main()
