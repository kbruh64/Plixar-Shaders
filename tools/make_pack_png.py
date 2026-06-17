#!/usr/bin/env python3
"""
Generate shaders/pack.png -- the 128x128 thumbnail shown in the shaderpack
selector. Pure stdlib (writes a PNG by hand), no Pillow dependency.

Draws a small "Minecraft sunset" scene: gradient sky, sun glow, distant hills,
and a water strip with a sun glint -- a visual summary of what the pack does.
"""

import struct
import zlib
import math
from pathlib import Path

W = H = 128
OUT = Path(__file__).resolve().parent.parent / "shaders" / "pack.png"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render():
    px = bytearray()
    horizon = int(H * 0.62)
    water_top = int(H * 0.74)

    # Palette
    sky_top = (28, 42, 96)
    sky_mid = (122, 96, 150)
    sky_horizon = (250, 168, 96)
    sun = (255, 244, 200)
    hill_far = (70, 70, 110)
    hill_near = (44, 58, 64)
    water_deep = (16, 44, 70)
    water_light = (120, 170, 200)

    sun_x, sun_y = int(W * 0.66), int(H * 0.40)

    for y in range(H):
        for x in range(W):
            if y < horizon:
                # Sky gradient with two stops.
                t = y / horizon
                if t < 0.5:
                    c = lerp(sky_top, sky_mid, t * 2.0)
                else:
                    c = lerp(sky_mid, sky_horizon, (t - 0.5) * 2.0)
                # Sun disc + glow.
                d = math.hypot(x - sun_x, y - sun_y)
                if d < 11:
                    c = sun
                else:
                    glow = max(0.0, 1.0 - d / 60.0) ** 2
                    c = tuple(min(255, int(c[i] + (sun[i] - c[i]) * glow * 0.8))
                              for i in range(3))
                # Distant hills silhouette near the horizon.
                hill = horizon - int(8 * (math.sin(x * 0.08) * 0.5 + 0.5)
                                     + 4 * math.sin(x * 0.21 + 1.0))
                if y >= hill:
                    c = hill_far
                hill2 = horizon - int(4 * (math.sin(x * 0.13 + 2.0) * 0.5 + 0.5))
                if y >= hill2:
                    c = hill_near
            elif y < water_top:
                c = hill_near
            else:
                # Water with a vertical sun-glint column and ripples.
                t = (y - water_top) / (H - water_top)
                c = lerp(water_light, water_deep, t)
                glint = max(0.0, 1.0 - abs(x - sun_x) / (6.0 + (y - water_top)))
                ripple = 0.5 + 0.5 * math.sin(y * 0.9 + x * 0.05)
                c = tuple(min(255, int(c[i] + (sun[i] - c[i]) * glint * ripple * 0.7))
                          for i in range(3))

            px.extend(c)
        # No per-row filter byte yet; we prepend below.

    # Build PNG: add filter byte (0) at the start of each row.
    raw = bytearray()
    stride = W * 3
    for y in range(H):
        raw.append(0)
        raw.extend(px[y * stride:(y + 1) * stride])
    return bytes(raw)


def chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)


def main():
    raw = render()
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)  # 8-bit RGB
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    OUT.write_bytes(png)
    print(f"wrote {OUT} ({len(png)} bytes)")


if __name__ == "__main__":
    main()
