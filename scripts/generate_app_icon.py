#!/usr/bin/env python3
"""Draw the Codex Reset Tracker icon: dark field, reset arc, small bolt."""

import struct
import zlib
from pathlib import Path


def write_png(path, width, height, rgba):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def render(size, background, arc, bolt, tinted=False):
    pixels = bytearray(size * size * 4)
    center = (size - 1) / 2
    outer = size * 0.34
    inner = size * 0.255
    samples = 4

    def coverage(px, py):
        hits = 0
        for sy in range(samples):
            for sx in range(samples):
                x = px + (sx + 0.5) / samples
                y = py + (sy + 0.5) / samples
                dx = x - center
                dy = y - center
                dist = (dx * dx + dy * dy) ** 0.5
                angle = __import__("math").atan2(dy, dx)
                # Gap near the upper right, where the arrow head sits.
                gap = -0.35 < angle < 0.45
                on_arc = inner <= dist <= outer and not gap
                on_head = arrow_head(dx, dy)
                on_bolt = lightning(dx / size, dy / size)
                if on_arc or on_head or on_bolt:
                    hits += 1
        return hits / (samples * samples)

    def arrow_head(dx, dy):
        # Base is the full thickness of the ring; the tip follows the tangent into the gap.
        math = __import__("math")
        base = -0.38
        inner_point = (inner * math.cos(base), inner * math.sin(base))
        outer_point = (outer * math.cos(base), outer * math.sin(base))
        mid_x = (inner_point[0] + outer_point[0]) / 2
        mid_y = (inner_point[1] + outer_point[1]) / 2
        tangent_x = -math.sin(base)
        tangent_y = math.cos(base)
        reach = (outer - inner) * 1.35
        tip = (mid_x + tangent_x * reach, mid_y + tangent_y * reach)
        return point_in_triangle(dx, dy, tip, inner_point, outer_point)

    for y in range(size):
        for x in range(size):
            cover = coverage(x, y)
            dx = (x + 0.5) - center
            dy = (y + 0.5) - center
            color = bolt if lightning(dx / size, dy / size) else arc
            if tinted:
                # Grayscale glyph on transparency so iOS can tint it.
                alpha = int(255 * cover)
                pixel = (255, 255, 255, alpha)
            else:
                pixel = mix(background, color, cover)
            offset = (y * size + x) * 4
            pixels[offset:offset + 4] = bytes(pixel)
    return pixels


def point_in_triangle(px, py, a, b, c):
    def sign(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])

    d1 = sign((px, py), a, b)
    d2 = sign((px, py), b, c)
    d3 = sign((px, py), c, a)
    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (has_neg and has_pos)


def lightning(nx, ny):
    # Small bolt in normalized coordinates around the center.
    points = [(-0.055, -0.11), (0.04, -0.11), (-0.012, -0.008), (0.07, -0.008), (-0.045, 0.13), (0.002, 0.02), (-0.07, 0.02)]
    return point_in_polygon(nx, ny, points)


def point_in_polygon(x, y, points):
    inside = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi):
            inside = not inside
        j = i
    return inside


def main():
    root = Path(__file__).resolve().parents[1] / "ios/CodexResetTracker/Resources/Assets.xcassets/AppIcon.appiconset"
    root.mkdir(parents=True, exist_ok=True)
    variants = {
        "AppIcon.png": ((22, 24, 32, 255), (242, 196, 92, 255), (255, 248, 230, 255), False),
        "AppIcon-Dark.png": ((8, 9, 12, 255), (255, 214, 120, 255), (255, 250, 235, 255), False),
        "AppIcon-Tinted.png": ((0, 0, 0, 0), (255, 255, 255, 255), (255, 255, 255, 255), True),
    }
    for name, (background, arc, bolt, tinted) in variants.items():
        pixels = render(1024, background, arc, bolt, tinted)
        write_png(root / name, 1024, 1024, pixels)
        print(name, (root / name).stat().st_size)


if __name__ == "__main__":
    main()
