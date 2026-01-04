#!/usr/bin/env python3
"""
Reconstruct overworld.json from Overworld_Map.png using overworld_tileset.png.

Reads the source map image, matches each tile to the extracted tileset,
and generates a Tiled-format JSON file for use in Godot.
"""

from PIL import Image
import hashlib
import json
import os

# Configuration (must match create_tileset.py)
TILE_SIZE = 16
SCREEN_TILES_X = 16
SCREEN_TILES_Y = 11
SCREENS_X = 16
SCREENS_Y = 9
SEPARATOR_WIDTH = 1

# Calculated values
SCREEN_WIDTH_PX = SCREEN_TILES_X * TILE_SIZE  # 256
SCREEN_HEIGHT_PX = SCREEN_TILES_Y * TILE_SIZE  # 176

# Tileset configuration (from overworld_tileset_metadata.json)
TILESET_COLUMNS = 16
TILESET_ROWS = 6

# Output map dimensions (no separators in output)
MAP_WIDTH_TILES = SCREENS_X * SCREEN_TILES_X  # 256
MAP_HEIGHT_TILES = SCREENS_Y * SCREEN_TILES_Y  # 99


def get_screen_pixel_origin(screen_x: int, screen_y: int) -> tuple[int, int]:
    """Calculate the top-left pixel coordinate for a screen, accounting for separators."""
    px_x = screen_x * (SCREEN_WIDTH_PX + SEPARATOR_WIDTH)
    px_y = screen_y * (SCREEN_HEIGHT_PX + SEPARATOR_WIDTH)
    return px_x, px_y


def extract_tile(img: Image.Image, screen_x: int, screen_y: int, tile_x: int, tile_y: int) -> Image.Image:
    """Extract a single 16x16 tile from the source map."""
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
    """Generate a hash of tile pixel data for matching."""
    # Convert to RGB to ensure consistent hashing regardless of source mode
    if tile.mode != "RGB":
        tile = tile.convert("RGB")
    return hashlib.md5(tile.tobytes()).hexdigest()


def build_tileset_lookup(tileset_path: str) -> dict[str, int]:
    """Build a hash-to-tile-ID lookup table from the tileset image."""
    print(f"Loading tileset: {tileset_path}")
    tileset = Image.open(tileset_path)

    lookup = {}
    tile_id = 0

    for row in range(TILESET_ROWS):
        for col in range(TILESET_COLUMNS):
            # Extract tile from tileset
            x = col * TILE_SIZE
            y = row * TILE_SIZE

            # Check if this tile exists (tileset may not be fully filled)
            if x + TILE_SIZE > tileset.width or y + TILE_SIZE > tileset.height:
                break

            tile = tileset.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))
            h = tile_hash(tile)
            lookup[h] = tile_id
            tile_id += 1

    print(f"Built lookup table with {len(lookup)} tiles")
    return lookup


def reconstruct_map(source_path: str, lookup: dict[str, int]) -> list[int]:
    """Reconstruct the tile map from the source image."""
    print(f"Loading source map: {source_path}")
    img = Image.open(source_path)
    print(f"Source image size: {img.width}x{img.height}")

    # Output array in row-major order (Tiled format uses 1-based IDs)
    map_data = []
    unmatched = 0

    total_tiles = SCREENS_X * SCREENS_Y * SCREEN_TILES_X * SCREEN_TILES_Y
    processed = 0

    # Iterate in the order that produces row-major output
    for screen_y in range(SCREENS_Y):
        for tile_y in range(SCREEN_TILES_Y):
            for screen_x in range(SCREENS_X):
                for tile_x in range(SCREEN_TILES_X):
                    tile = extract_tile(img, screen_x, screen_y, tile_x, tile_y)
                    h = tile_hash(tile)

                    if h in lookup:
                        # Tiled uses 1-based IDs (0 = empty)
                        tile_id = lookup[h] + 1
                    else:
                        tile_id = 0  # Unmatched tile
                        unmatched += 1

                    map_data.append(tile_id)
                    processed += 1

    print(f"Processed {processed} tiles")
    if unmatched > 0:
        print(f"WARNING: {unmatched} tiles could not be matched!")
    else:
        print("All tiles matched successfully")

    return map_data


def generate_json(map_data: list[int], output_path: str, tileset_path: str) -> None:
    """Generate Tiled-format JSON file."""

    # Get tileset image dimensions for metadata
    tileset = Image.open(tileset_path)
    tile_count = (tileset.width // TILE_SIZE) * (tileset.height // TILE_SIZE)

    tiled_json = {
        "compressionlevel": -1,
        "height": MAP_HEIGHT_TILES,
        "width": MAP_WIDTH_TILES,
        "infinite": False,
        "orientation": "orthogonal",
        "renderorder": "right-down",
        "tiledversion": "1.10.0",
        "tileheight": TILE_SIZE,
        "tilewidth": TILE_SIZE,
        "type": "map",
        "version": "1.10",
        "layers": [
            {
                "data": map_data,
                "height": MAP_HEIGHT_TILES,
                "width": MAP_WIDTH_TILES,
                "id": 1,
                "name": "terrain",
                "opacity": 1,
                "type": "tilelayer",
                "visible": True,
                "x": 0,
                "y": 0
            }
        ],
        "tilesets": [
            {
                "columns": TILESET_COLUMNS,
                "firstgid": 1,
                "image": "overworld_tileset.png",
                "imageheight": tileset.height,
                "imagewidth": tileset.width,
                "margin": 0,
                "name": "overworld_tiles",
                "spacing": 0,
                "tilecount": tile_count,
                "tileheight": TILE_SIZE,
                "tilewidth": TILE_SIZE
            }
        ],
        "properties": [
            {"name": "screen_width", "type": "int", "value": SCREEN_TILES_X},
            {"name": "screen_height", "type": "int", "value": SCREEN_TILES_Y},
            {"name": "screens_wide", "type": "int", "value": SCREENS_X},
            {"name": "screens_tall", "type": "int", "value": SCREENS_Y}
        ]
    }

    with open(output_path, "w") as f:
        json.dump(tiled_json, f, indent=2)

    print(f"Saved overworld.json to: {output_path}")
    print(f"Map dimensions: {MAP_WIDTH_TILES}x{MAP_HEIGHT_TILES} tiles")


def main():
    home = os.path.expanduser("~")

    # Paths
    source_path = os.path.join(home, "Downloads", "Overworld_Map.png")
    tileset_path = os.path.join(home, "devprojects", "super_adventure", "assets", "overworld_tileset.png")
    output_path = os.path.join(home, "devprojects", "super_adventure", "assets", "overworld.json")

    # Build lookup table from tileset
    lookup = build_tileset_lookup(tileset_path)

    # Reconstruct map data
    map_data = reconstruct_map(source_path, lookup)

    # Generate JSON
    generate_json(map_data, output_path, tileset_path)

    print("\nDone!")


if __name__ == "__main__":
    main()
