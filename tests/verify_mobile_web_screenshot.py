#!/usr/bin/env python3
from pathlib import Path
import struct
import sys
import zlib


def decode_png_rgb(path: Path):
    data = path.read_bytes()
    signature = b"\x89PNG\r\n\x1a\n"
    if not data.startswith(signature):
        raise SystemExit("Web smoke screenshot is not a PNG")

    pos = len(signature)
    width = height = bit_depth = color_type = interlace = None
    compressed = bytearray()
    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filter, interlace = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break

    if (width, height) != (390, 700):
        raise SystemExit(f"Unexpected Web smoke size: {width}x{height}")
    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise SystemExit(
            f"Unsupported PNG format bit_depth={bit_depth} color_type={color_type} interlace={interlace}"
        )

    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise SystemExit(f"Unexpected decompressed PNG size: {len(raw)} != {expected}")

    def paeth(a, b, c):
        p = a + b - c
        pa = abs(p - a)
        pb = abs(p - b)
        pc = abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        if pb <= pc:
            return b
        return c

    previous = bytearray(stride)
    rows = []
    offset = 0
    for _y in range(height):
        filter_type = raw[offset]
        offset += 1
        scan = bytearray(raw[offset:offset + stride])
        offset += stride
        for i in range(stride):
            left = scan[i - channels] if i >= channels else 0
            up = previous[i]
            up_left = previous[i - channels] if i >= channels else 0
            if filter_type == 1:
                scan[i] = (scan[i] + left) & 0xFF
            elif filter_type == 2:
                scan[i] = (scan[i] + up) & 0xFF
            elif filter_type == 3:
                scan[i] = (scan[i] + ((left + up) >> 1)) & 0xFF
            elif filter_type == 4:
                scan[i] = (scan[i] + paeth(left, up, up_left)) & 0xFF
            elif filter_type != 0:
                raise SystemExit(f"Unsupported PNG filter {filter_type}")
        rows.append(scan)
        previous = scan

    return width, height, channels, rows


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "qa-web/mobile-390x700.png")
    if not path.is_file() or path.stat().st_size == 0:
        print(f"Web smoke screenshot missing: {path}", file=sys.stderr)
        return 1

    width, _height, channels, rows = decode_png_rgb(path)
    gold = 0
    loader_blue = 0
    for scan in rows:
        for x in range(width):
            base = x * channels
            r, g, b = scan[base], scan[base + 1], scan[base + 2]
            if r >= 150 and 105 <= g <= 220 and b <= 140 and r >= int(g * 0.9):
                gold += 1
            if b >= 150 and g >= 70 and r <= 120 and b >= int(r * 1.5):
                loader_blue += 1

    print(f"WEB_PORTRAIT_PIXEL_QA gold={gold} loader_blue={loader_blue}")
    if gold < 500:
        print("Real title screen not detected: insufficient gold title pixels", file=sys.stderr)
        return 1
    if loader_blue > 1500:
        print("Godot loader/progress bar still dominates the screenshot", file=sys.stderr)
        return 1

    print("WEB_PORTRAIT_PIXEL_QA: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
