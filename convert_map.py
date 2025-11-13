#!/usr/bin/env python3
"""
Convert Ant Attack map.scad to JSON format for iOS game.

The map.scad file contains a 128x128 array where each value (0-63) is a 9-bit
bitmap encoding which Z-levels (0-8) have blocks present.
"""

import json
import re


def parse_scad_map(scad_file):
    """Parse the OpenSCAD map file and extract the 2D array."""
    with open(scad_file, "r") as f:
        content = f.read()

    # Extract the map array using regex
    # Find "map=[" and capture until the closing "];"
    match = re.search(r"map=\[(.*?)\];", content, re.DOTALL)
    if not match:
        raise ValueError("Could not find map array in file")

    map_content = match.group(1)

    # Split by rows (each row starts with '[' and ends with '],')
    rows = []
    for line in map_content.split("\n"):
        line = line.strip()
        if line.startswith("["):
            # Extract numbers from this row
            # Remove brackets and split by comma
            numbers_str = line.strip("[],")
            if numbers_str:
                # Split by comma and convert to integers
                numbers = [int(x.strip()) for x in numbers_str.split(",") if x.strip()]
                rows.append(numbers)

    return rows


def convert_to_json(heightmap, output_file):
    """Convert height map to JSON format for the iOS game."""

    # Calculate statistics
    total_cells = len(heightmap) * len(heightmap[0])
    ground_only = sum(1 for row in heightmap for val in row if val == 0)
    elevated = total_cells - ground_only

    # Count total blocks (decode all bitmaps)
    total_blocks = 0
    for row in heightmap:
        for val in row:
            # Count set bits in the value
            for z in range(9):
                if (val >> z) & 1:
                    total_blocks += 1

    print(f"Map Statistics:")
    print(f"  Size: {len(heightmap[0])}x{len(heightmap)}")
    print(
        f"  Ground-only cells: {ground_only} ({100 * ground_only / total_cells:.1f}%)"
    )
    print(f"  Elevated cells: {elevated} ({100 * elevated / total_cells:.1f}%)")
    print(f"  Total blocks: {total_blocks}")

    # Create JSON structure
    map_data = {
        "name": "Ant Attack Original",
        "width": len(heightmap[0]),
        "height": len(heightmap),
        "maxLevels": 9,
        "heightMap": heightmap,
        "blocks": [],  # Empty - using heightMap format
        "ramps": [],  # No ramps in original Ant Attack
        "createdAt": "2025-01-01T00:00:00Z",
    }

    # Write to file
    with open(output_file, "w") as f:
        json.dump(map_data, f, indent=2)

    print(f"\n✅ Converted map to: {output_file}")
    print(f"   Size: {map_data['width']}x{map_data['height']}x{map_data['maxLevels']}")


def main():
    scad_file = "AntAttack3D/map.scad"
    output_file = "AntAttack3D/ant_attack_original.json"

    print("Converting Ant Attack map from OpenSCAD to JSON...")
    print(f"Input:  {scad_file}")
    print(f"Output: {output_file}")
    print()

    # Parse the SCAD file
    heightmap = parse_scad_map(scad_file)
    print(f"✅ Parsed {len(heightmap)} rows from {scad_file}")

    # Convert to JSON
    convert_to_json(heightmap, output_file)

    # Test decoding a few values
    print("\nSample bitmap decoding:")
    test_values = [0, 15, 63, 59, 31]
    for val in test_values:
        blocks = []
        for z in range(9):
            if (val >> z) & 1:
                blocks.append(z)
        if blocks:
            print(f"  Value {val:2d} (0b{val:09b}) = blocks at Z-levels: {blocks}")
        else:
            print(f"  Value {val:2d} (0b{val:09b}) = no blocks (ground only)")


if __name__ == "__main__":
    main()
