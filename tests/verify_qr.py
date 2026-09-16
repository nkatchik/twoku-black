"""Verify pixels emitted by production BrightScript against reference QR matrices."""
import argparse
import json
from pathlib import Path


def verify(output, decode=False):
    expected = json.loads(Path(__file__).with_name('qr_expected.json').read_text())
    fixtures = [json.loads(line[len('QR_FIXTURE '):]) for line in output.splitlines() if line.startswith('QR_FIXTURE ')]
    assert len(fixtures) == len(expected), 'Missing QR fixtures'
    for fixture, golden in zip(fixtures, expected):
        assert fixture['url'] == golden['url'], 'Wrong activation URL'
        pixels = [[0] * 360 for _ in range(360)]
        for x, y, width, height, color in fixture['draws']:
            assert all(isinstance(n, int) for n in [x, y, width, height]), 'Fractional QR pixels'
            for row in range(y, y + height):
                pixels[row][x:x + width] = [int(color == 255)] * width
        matrix = golden['matrix']
        scale = 360 // (len(matrix) + 8)
        offset = (360 - len(matrix) * scale) // 2
        for y in range(360):
            for x in range(360):
                mx, my = (x - offset) // scale, (y - offset) // scale
                dark = int(matrix[my][mx]) if 0 <= mx < len(matrix) and 0 <= my < len(matrix) else 0
                assert pixels[y][x] == dark, f'QR differs from reference at ({x}, {y})'
        if decode:
            from PIL import Image
            import zxingcpp
            image = Image.new('L', (360, 360))
            image.putdata([255 * (1 - pixel) for row in pixels for pixel in row])
            result = zxingcpp.read_barcode(image)
            assert result and result.text == fixture['url'], 'QR does not decode to the complete activation URL'
    return len(fixtures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--decode', action='store_true')
    args = parser.parse_args()
    print(f'PASS {verify(args.output.read_text(), args.decode)} QR images match independent references' + (' and decode exactly' if args.decode else ''))
