#!/usr/bin/env python3
"""Renders the Sprinkles assistant avatar into the iOS app icon.

The avatar is drawn in the app with SwiftUI shapes (CrazyCakes/Assistant/
AssistantAvatar.swift, ported from src/assistant/AvatarFace.tsx), so this script
replays the same geometry to produce CrazyCakes/Resources/Assets.xcassets/
AppIcon.appiconset/AppIcon-1024.png.

Run from the repo root with Pillow installed:

    python scripts/render-app-icon.py
"""

import math
import os

from PIL import Image, ImageDraw

# Design tokens (CrazyCakes/Core/Theme.swift).
BLUSH = (255, 244, 244)
PRIMARY = (229, 143, 146)
BORDER = (234, 218, 217)
HAIR = (107, 65, 48)
SKIN = (247, 213, 189)
EYE = (59, 42, 34)
MOUTH = (162, 62, 74)
WHITE = (255, 255, 255)

# Icon backdrop: the blush tile, a touch deeper at the top so the white toque reads.
GRADIENT_TOP = (237, 169, 173)
GRADIENT_BOTTOM = (255, 249, 248)

ICON = 1024
MARGIN = 0.075      # share of the tile left empty around the portrait
UNIT = 40.0         # render pixels per avatar viewBox unit (supersampled)
CANVAS = 5000
CX = CY = 60.0      # avatar viewBox centre

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.join(
    HERE, "..", "CrazyCakes", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png"
)


def px(x, y):
    return ((x - CX) * UNIT + CANVAS / 2, (y - CY) * UNIT + CANVAS / 2)


def cubic(p0, p1, p2, p3, steps=96):
    points = []
    for i in range(steps + 1):
        t = i / steps
        m = 1 - t
        points.append((
            m**3 * p0[0] + 3 * m**2 * t * p1[0] + 3 * m * t**2 * p2[0] + t**3 * p3[0],
            m**3 * p0[1] + 3 * m**2 * t * p1[1] + 3 * m * t**2 * p2[1] + t**3 * p3[1],
        ))
    return points


def quad(p0, p1, p2, steps=64):
    points = []
    for i in range(steps + 1):
        t = i / steps
        m = 1 - t
        points.append((
            m**2 * p0[0] + 2 * m * t * p1[0] + t**2 * p2[0],
            m**2 * p0[1] + 2 * m * t * p1[1] + t**2 * p2[1],
        ))
    return points


def chain(*segments):
    points = []
    for segment in segments:
        points.extend(segment if not points else segment[1:])
    return points


# SVG paths from AvatarFace.tsx.
HAIR_PATH = chain(
    cubic((30, 70), (30, 46), (43, 32), (60, 32)),
    cubic((60, 32), (77, 32), (107, 46), (90, 70)),
    [(90, 86)],
    cubic((90, 86), (84, 82), (81, 72), (81, 62)),
    cubic((81, 62), (70, 68), (50, 69), (39, 62)),
    cubic((39, 62), (39, 72), (36, 82), (30, 86)),
)

HAT_PATH = chain(
    cubic((37, 44), (28, 43), (25, 31), (33, 26)),
    cubic((33, 26), (36, 17), (48, 16), (52, 23)),
    cubic((52, 23), (57, 16), (68, 16), (72, 23)),
    cubic((72, 23), (79, 19), (88, 24), (87, 32)),
    cubic((87, 32), (94, 36), (90, 46), (82, 45)),
    [(82, 52), (37, 52)],
)


def scaled(points):
    return [px(x, y) for x, y in points]


def fill(draw, points, color):
    draw.polygon(scaled(points), fill=color)


def stroke(draw, points, color, width_units, closed=False):
    """Expands a polyline into a filled ribbon (SVG-style centred stroke)."""
    width = width_units * UNIT
    points = scaled(points)
    if closed:
        points = points + [points[0]]
    count = len(points)
    left, right = [], []
    for i, point in enumerate(points):
        if i == 0:
            tangent = (points[1][0] - points[0][0], points[1][1] - points[0][1])
        elif i == count - 1:
            tangent = (points[-1][0] - points[-2][0], points[-1][1] - points[-2][1])
        else:
            tangent = (points[i + 1][0] - points[i - 1][0], points[i + 1][1] - points[i - 1][1])
        length = math.hypot(*tangent) or 1.0
        nx, ny = -tangent[1] / length, tangent[0] / length
        left.append((point[0] + nx * width / 2, point[1] + ny * width / 2))
        right.append((point[0] - nx * width / 2, point[1] - ny * width / 2))
    draw.polygon(left + right[::-1], fill=color)
    if not closed:
        radius = width / 2
        for point in (points[0], points[-1]):
            draw.ellipse(
                [point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius],
                fill=color,
            )


def ellipse(draw, cx, cy, rx, ry, color):
    x0, y0 = px(cx - rx, cy - ry)
    x1, y1 = px(cx + rx, cy + ry)
    draw.ellipse([x0, y0, x1, y1], fill=color)


def circle(draw, cx, cy, radius, color):
    ellipse(draw, cx, cy, radius, radius, color)


def draw_portrait():
    """Idle-mood portrait: hair, face, chef hat, eyes, cheeks, smile."""
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    fill(draw, HAIR_PATH, HAIR + (255,))
    ellipse(draw, 60, 70, 25, 27, SKIN + (255,))

    fill(draw, HAT_PATH, WHITE + (255,))
    stroke(draw, HAT_PATH, BORDER + (255,), 1.5, closed=True)

    # Hat band: primary ring around a white centre (the SVG rect stroke).
    band = [px(36, 44)[0], px(36, 44)[1], px(84, 52)[0], px(84, 52)[1]]
    draw.rounded_rectangle(band, radius=2.5 * UNIT + 0.75 * UNIT, fill=PRIMARY + (255,))
    inset = 1.5 * UNIT
    draw.rounded_rectangle(
        [band[0] + inset, band[1] + inset, band[2] - inset, band[3] - inset],
        radius=max(1, 1.75 * UNIT),
        fill=WHITE + (255,),
    )
    circle(draw, 60, 48, 2, PRIMARY + (255,))

    ellipse(draw, 50, 67, 3.3, 4, EYE + (255,))
    ellipse(draw, 70, 67, 3.3, 4, EYE + (255,))
    circle(draw, 51.2, 65.6, 1.1, WHITE + (255,))
    circle(draw, 71.2, 65.6, 1.1, WHITE + (255,))

    stroke(draw, quad((45, 59), (50, 56), (55, 59)), HAIR + (255,), 2)
    stroke(draw, quad((65, 59), (70, 56), (75, 59)), HAIR + (255,), 2)

    cheeks = Image.new("RGBA", image.size, (0, 0, 0, 0))
    cheek_draw = ImageDraw.Draw(cheeks)
    circle(cheek_draw, 44, 78, 4.5, PRIMARY + (90,))
    circle(cheek_draw, 76, 78, 4.5, PRIMARY + (90,))
    image.alpha_composite(cheeks)

    draw = ImageDraw.Draw(image)
    stroke(draw, quad((51, 83), (60, 91), (69, 83)), MOUTH + (255,), 3)
    return image


def blush_gradient():
    base = Image.new("RGBA", (ICON, ICON))
    draw = ImageDraw.Draw(base)
    for y in range(ICON):
        t = y / (ICON - 1)
        color = tuple(round(GRADIENT_TOP[i] + (GRADIENT_BOTTOM[i] - GRADIENT_TOP[i]) * t) for i in range(3))
        draw.line([(0, y), (ICON, y)], fill=color + (255,))
    return base


def main():
    portrait = draw_portrait()
    portrait = portrait.crop(portrait.getbbox())

    target = int(round(ICON * (1 - 2 * MARGIN)))
    scale = target / max(portrait.size)
    portrait = portrait.resize(
        (max(1, round(portrait.size[0] * scale)), max(1, round(portrait.size[1] * scale))),
        Image.LANCZOS,
    )

    icon = blush_gradient()
    icon.alpha_composite(portrait, ((ICON - portrait.size[0]) // 2, (ICON - portrait.size[1]) // 2))
    icon = icon.convert("RGB")
    icon.save(OUTPUT, "PNG", optimize=True)
    print("wrote", os.path.relpath(OUTPUT), icon.size, icon.mode, os.path.getsize(OUTPUT), "bytes")


if __name__ == "__main__":
    main()
