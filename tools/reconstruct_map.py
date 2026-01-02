#!/usr/local/bin/python3
"""
Overworld Map Reconstruction Tool

Extracts tiles from a tileset, matches them to an overworld map,
and generates Tiled-compatible JSON output for Godot.
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Tuple
from PIL import Image
import numpy as np

# Configuration
TILE_SIZE = 16
SCREEN_WIDTH_TILES = 16
SCREEN_HEIGHT_TILES = 11
SCREENS_WIDE = 16
SCREENS_TALL = 8

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
ASSETS_DIR = PROJECT_DIR / "assets"

# Source files
TILESET_PATH = Path.home() / "Downloads" / "Overworld_Tileset.png"
MAP_PATH = Path.home() / "Downloads" / "Overworld_Map.png"


def extract_tile(image: Image.Image, x: int, y: int) -> np.ndarray:
    """Extract a single tile from an image at the given pixel coordinates."""
    tile = image.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))
    return np.array(tile)


def tile_hash(tile: np.ndarray) -> bytes:
    """Create a hash for a tile to identify unique tiles."""
    return tile.tobytes()


def extract_unique_tiles_from_map(map_image: Image.Image) -> Tuple[Dict[bytes, int], List[np.ndarray]]:
    """
    Extract all unique tiles from the overworld map.
    Returns a mapping of tile hash -> tile ID and a list of tile arrays.
    """
    width, height = map_image.size
    tiles_x = width // TILE_SIZE
    tiles_y = height // TILE_SIZE

    tile_to_id: Dict[bytes, int] = {}
    unique_tiles: List[np.ndarray] = []

    print(f"Scanning map: {tiles_x}x{tiles_y} tiles ({width}x{height} pixels)")

    for ty in range(tiles_y):
        for tx in range(tiles_x):
            px, py = tx * TILE_SIZE, ty * TILE_SIZE
            tile = extract_tile(map_image, px, py)
            h = tile_hash(tile)

            if h not in tile_to_id:
                tile_id = len(unique_tiles)
                tile_to_id[h] = tile_id
                unique_tiles.append(tile)

    print(f"Found {len(unique_tiles)} unique tiles")
    return tile_to_id, unique_tiles


def build_tile_map(map_image: Image.Image, tile_to_id: Dict[bytes, int]) -> List[List[int]]:
    """
    Build a 2D array of tile IDs representing the full map.
    """
    width, height = map_image.size
    tiles_x = width // TILE_SIZE
    tiles_y = height // TILE_SIZE

    tilemap: List[List[int]] = []

    for ty in range(tiles_y):
        row = []
        for tx in range(tiles_x):
            px, py = tx * TILE_SIZE, ty * TILE_SIZE
            tile = extract_tile(map_image, px, py)
            h = tile_hash(tile)
            tile_id = tile_to_id[h]
            # Tiled uses 1-based tile IDs (0 means empty)
            row.append(tile_id + 1)
        tilemap.append(row)

    return tilemap


def create_tileset_image(unique_tiles: List[np.ndarray], output_path: Path) -> Tuple[int, int]:
    """
    Create an organized tileset image from unique tiles.
    Returns (tiles_per_row, total_rows) for Tiled configuration.
    """
    num_tiles = len(unique_tiles)
    # Arrange in a square-ish grid
    tiles_per_row = int(np.ceil(np.sqrt(num_tiles)))
    num_rows = int(np.ceil(num_tiles / tiles_per_row))

    # Create output image
    out_width = tiles_per_row * TILE_SIZE
    out_height = num_rows * TILE_SIZE

    tileset_image = Image.new("RGBA", (out_width, out_height), (0, 0, 0, 0))

    for idx, tile_array in enumerate(unique_tiles):
        tx = idx % tiles_per_row
        ty = idx // tiles_per_row
        px, py = tx * TILE_SIZE, ty * TILE_SIZE

        tile_img = Image.fromarray(tile_array)
        tileset_image.paste(tile_img, (px, py))

    tileset_image.save(output_path)
    print(f"Created tileset: {output_path} ({tiles_per_row}x{num_rows} tiles)")

    return tiles_per_row, num_rows


def generate_tiled_json(
    tilemap: List[List[int]],
    tileset_path: str,
    tiles_per_row: int,
    num_tiles: int,
    output_path: Path
):
    """
    Generate a Tiled-compatible JSON tilemap.
    """
    map_width = len(tilemap[0])
    map_height = len(tilemap)

    # Flatten tilemap for Tiled format (row-major, 1D array)
    flat_data = []
    for row in tilemap:
        flat_data.extend(row)

    tiled_map = {
        "compressionlevel": -1,
        "height": map_height,
        "width": map_width,
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
                "data": flat_data,
                "height": map_height,
                "width": map_width,
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
                "columns": tiles_per_row,
                "firstgid": 1,
                "image": tileset_path,
                "imageheight": (num_tiles // tiles_per_row + 1) * TILE_SIZE,
                "imagewidth": tiles_per_row * TILE_SIZE,
                "margin": 0,
                "name": "overworld_tiles",
                "spacing": 0,
                "tilecount": num_tiles,
                "tileheight": TILE_SIZE,
                "tilewidth": TILE_SIZE
            }
        ],
        "properties": [
            {
                "name": "screen_width",
                "type": "int",
                "value": SCREEN_WIDTH_TILES
            },
            {
                "name": "screen_height",
                "type": "int",
                "value": SCREEN_HEIGHT_TILES
            },
            {
                "name": "screens_wide",
                "type": "int",
                "value": SCREENS_WIDE
            },
            {
                "name": "screens_tall",
                "type": "int",
                "value": SCREENS_TALL
            }
        ]
    }

    with open(output_path, "w") as f:
        json.dump(tiled_map, f, indent=2)

    print(f"Created tilemap: {output_path}")


def generate_screen_metadata(output_path: Path):
    """
    Generate screen boundary metadata for game logic.
    """
    screens = []

    for sy in range(SCREENS_TALL):
        for sx in range(SCREENS_WIDE):
            screen_id = sy * SCREENS_WIDE + sx
            screens.append({
                "id": screen_id,
                "grid_x": sx,
                "grid_y": sy,
                "tile_x": sx * SCREEN_WIDTH_TILES,
                "tile_y": sy * SCREEN_HEIGHT_TILES,
                "pixel_x": sx * SCREEN_WIDTH_TILES * TILE_SIZE,
                "pixel_y": sy * SCREEN_HEIGHT_TILES * TILE_SIZE,
                "width_tiles": SCREEN_WIDTH_TILES,
                "height_tiles": SCREEN_HEIGHT_TILES
            })

    metadata = {
        "tile_size": TILE_SIZE,
        "screen_width_tiles": SCREEN_WIDTH_TILES,
        "screen_height_tiles": SCREEN_HEIGHT_TILES,
        "screen_width_pixels": SCREEN_WIDTH_TILES * TILE_SIZE,
        "screen_height_pixels": SCREEN_HEIGHT_TILES * TILE_SIZE,
        "total_screens_wide": SCREENS_WIDE,
        "total_screens_tall": SCREENS_TALL,
        "total_screens": SCREENS_WIDE * SCREENS_TALL,
        "screens": screens
    }

    with open(output_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"Created screen metadata: {output_path}")


def main():
    print("=" * 60)
    print("Overworld Map Reconstruction Tool")
    print("=" * 60)

    # Create output directory
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    # Load source images
    print(f"\nLoading map: {MAP_PATH}")
    map_image = Image.open(MAP_PATH).convert("RGBA")

    print(f"Map dimensions: {map_image.size[0]}x{map_image.size[1]} pixels")

    # Extract unique tiles from the map itself
    print("\nExtracting unique tiles from map...")
    tile_to_id, unique_tiles = extract_unique_tiles_from_map(map_image)

    # Build the tilemap
    print("\nBuilding tilemap...")
    tilemap = build_tile_map(map_image, tile_to_id)

    # Create organized tileset image
    print("\nCreating tileset image...")
    tileset_output = ASSETS_DIR / "tileset.png"
    tiles_per_row, num_rows = create_tileset_image(unique_tiles, tileset_output)

    # Generate Tiled JSON
    print("\nGenerating Tiled JSON...")
    tiled_output = ASSETS_DIR / "overworld.json"
    generate_tiled_json(
        tilemap,
        "tileset.png",  # Relative path for Tiled
        tiles_per_row,
        len(unique_tiles),
        tiled_output
    )

    # Generate screen metadata
    print("\nGenerating screen metadata...")
    screens_output = ASSETS_DIR / "screens.json"
    generate_screen_metadata(screens_output)

    print("\n" + "=" * 60)
    print("Reconstruction complete!")
    print("=" * 60)
    print(f"\nOutput files:")
    print(f"  - {tileset_output}")
    print(f"  - {tiled_output}")
    print(f"  - {screens_output}")
    print(f"\nStats:")
    print(f"  - Unique tiles: {len(unique_tiles)}")
    print(f"  - Map size: {len(tilemap[0])}x{len(tilemap)} tiles")
    print(f"  - Screens: {SCREENS_WIDE}x{SCREENS_TALL} ({SCREENS_WIDE * SCREENS_TALL} total)")


if __name__ == "__main__":
    main()
