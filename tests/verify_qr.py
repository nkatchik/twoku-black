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
            assert 0 <= x < x + width <= 360 and 0 <= y < y + height <= 360, 'Drawing outside QR canvas'
            for row in range(y, y + height):
                pixels[row][x:x + width] = [color & 0xFFFFFFFF] * width
        matrix = golden['matrix']
        scale = 360 // (len(matrix) + 8)
        card_side = (len(matrix) + 6) * scale
        card_offset = (360 - card_side) // 2
        offset = card_offset + 3 * scale
        white, black, background = 0xFFFFFFFF, 0x000000FF, 0xFFFFFF00
        for y in range(card_offset, card_offset + card_side):
            for x in range(card_offset, card_offset + card_side):
                mx, my = (x - offset) // scale, (y - offset) // scale
                in_x, in_y = 0 <= mx < len(matrix), 0 <= my < len(matrix)
                if in_x and in_y:
                    expected_pixel = black if int(matrix[my][mx]) else white
                    assert pixels[y][x] == expected_pixel, f'QR differs from reference at ({x}, {y})'
                elif in_x or in_y:
                    assert pixels[y][x] == white, 'Three-module border must stay white along every side'
        middle = 180
        assert sum(row[middle] == white for row in pixels[:offset]) == 3 * scale, 'Excess top padding'
        assert sum(pixel == white for pixel in pixels[middle][:offset]) == 3 * scale, 'Excess left padding'
        for x, y in [(card_offset, card_offset), (card_offset + card_side - 1, card_offset),
                     (card_offset, card_offset + card_side - 1), (card_offset + card_side - 1, card_offset + card_side - 1)]:
            assert pixels[y][x] == background, 'Card corners must be rounded'
        edge_alphas = {pixel & 255 for row in pixels for pixel in row if 0 < (pixel & 255) < 255}
        assert len(edge_alphas) >= 6, 'Rounded edges need a smooth range of partial alpha coverage'
        assert all(pixels[y] == pixels[359 - y] for y in range(card_offset)), 'Canvas stays centered'
        if decode:
            from PIL import Image
            import zxingcpp
            image = Image.new('RGBA', (360, 360))
            image.putdata([((pixel >> 24) & 255, (pixel >> 16) & 255, (pixel >> 8) & 255, pixel & 255)
                           for row in pixels for pixel in row])
            image = Image.alpha_composite(Image.new('RGBA', image.size, (8, 8, 10, 255)), image).convert('RGB')
            result = zxingcpp.read_barcode(image)
            assert result and result.text == fixture['url'], 'QR does not decode to the complete activation URL'
            result = zxingcpp.read_barcode(image.resize((180, 180), Image.Resampling.LANCZOS))
            assert result and result.text == fixture['url'], 'QR does not decode at half size'
    return len(fixtures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--decode', action='store_true')
    args = parser.parse_args()
    print(f'PASS {verify(args.output.read_text(), args.decode)} QR images match independent references' + (' and decode exactly' if args.decode else ''))
