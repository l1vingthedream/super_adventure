#!/usr/bin/env python3
"""
Extract unique 16x16 tiles from the Legend of Zelda overworld map.

Source: ~/Downloads/Overworld_Map.png (4111x1592px)
- 16 screens wide x 9 screens tall
- Each screen: 16 tiles wide x 11 tiles tall
- Each tile: 16x16 pixels
- 1px green separator between screens
"""

from PIL import Image
import hashlib
import os

# Configuration
TILE_SIZE = 16
SCREEN_TILES_X = 16
SCREEN_TILES_Y = 11
SCREENS_X = 16
SCREENS_Y = 9
SEPARATOR_WIDTH = 1

# Calculated values
SCREEN_WIDTH_PX = SCREEN_TILES_X * TILE_SIZE  # 256
SCREEN_HEIGHT_PX = SCREEN_TILES_Y * TILE_SIZE  # 176

# Output configuration
OUTPUT_TILES_PER_ROW = 16


def get_screen_pixel_origin(screen_x: int, screen_y: int) -> tuple[int, int]:
    """Calculate the top-left pixel coordinate for a screen, accounting for separators."""
    # Each screen is separated by 1px green line
    # Screen 0 starts at 0, screen 1 starts at 257 (256 + 1), etc.
    px_x = screen_x * (SCREEN_WIDTH_PX + SEPARATOR_WIDTH)
    px_y = screen_y * (SCREEN_HEIGHT_PX + SEPARATOR_WIDTH)
    return px_x, px_y


def extract_tile(img: Image.Image, screen_x: int, screen_y: int, tile_x: int, tile_y: int) -> Image.Image:
    """Extract a single 16x16 tile from the map."""
    screen_origin_x, screen_origin_y = get_screen_pixel_origin(screen_x, screen_y)

    tile_px_x = screen_origin_x + tile_x * TILE_SIZE
    tile_px_y = screen_origin_y + tile_y * TILE_SIZE

    return img.crop((
        tile_px_x,
        tile_px_y,
        tile_px_x + TILE_SIZE,
        tile_px_y + TILE_SIZE
    ))


def tile_hash(tile: Image.Image) -> str:
    """Generate a hash of tile pixel data for deduplication."""
    return hashlib.md5(tile.tobytes()).hexdigest()


def main():
    # Paths
    home = os.path.expanduser("~")
    input_path = os.path.join(home, "Downloads", "Overworld_Map.png")
    output_path = os.path.join(home, "devprojects", "super_adventure", "assets", "overworld_tileset.png")

    print(f"Loading source image: {input_path}")
    img = Image.open(input_path)
    print(f"Image size: {img.width}x{img.height}")

    # Verify dimensions
    expected_width = SCREENS_X * SCREEN_WIDTH_PX + (SCREENS_X - 1) * SEPARATOR_WIDTH
    expected_height = SCREENS_Y * SCREEN_HEIGHT_PX + (SCREENS_Y - 1) * SEPARATOR_WIDTH
    print(f"Expected size: {expected_width}x{expected_height}")

    if img.width != expected_width or img.height != expected_height:
        print(f"WARNING: Image dimensions don't match expected!")

    # Extract all tiles and deduplicate
    unique_tiles = {}  # hash -> tile image
    tile_order = []    # preserve first occurrence order

    total_tiles = SCREENS_X * SCREENS_Y * SCREEN_TILES_X * SCREEN_TILES_Y
    processed = 0

    print(f"\nExtracting tiles from {SCREENS_X}x{SCREENS_Y} screens...")

    for screen_y in range(SCREENS_Y):
        for screen_x in range(SCREENS_X):
            for tile_y in range(SCREEN_TILES_Y):
                for tile_x in range(SCREEN_TILES_X):
                    tile = extract_tile(img, screen_x, screen_y, tile_x, tile_y)
                    h = tile_hash(tile)

                    if h not in unique_tiles:
                        unique_tiles[h] = tile
                        tile_order.append(h)

                    processed += 1

    print(f"Processed {processed} tiles")
    print(f"Found {len(unique_tiles)} unique tiles")

    # Create output tileset image
    num_unique = len(unique_tiles)
    rows = (num_unique + OUTPUT_TILES_PER_ROW - 1) // OUTPUT_TILES_PER_ROW

    output_width = OUTPUT_TILES_PER_ROW * TILE_SIZE
    output_height = rows * TILE_SIZE

    print(f"\nCreating output tileset: {output_width}x{output_height} ({OUTPUT_TILES_PER_ROW}x{rows} tiles)")

    output_img = Image.new("RGB", (output_width, output_height), (0, 0, 0))

    for i, h in enumerate(tile_order):
        tile = unique_tiles[h]
        out_x = (i % OUTPUT_TILES_PER_ROW) * TILE_SIZE
        out_y = (i // OUTPUT_TILES_PER_ROW) * TILE_SIZE
        output_img.paste(tile, (out_x, out_y))

    output_img.save(output_path)
    print(f"\nSaved tileset to: {output_path}")


if __name__ == "__main__":
    main()
