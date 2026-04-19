import json

classic_tiles = {
    2:     "#eee4da",
    4:     "#ede0c8",
    8:     "#f2b179",
    16:    "#f59563",
    32:    "#f67c5f",
    64:    "#f65e3b",
    128:   "#edcf72",
    256:   "#edcc61",
    512:   "#edc850",
    1024:  "#edc53f",
    2048:  "#edc22e",
    4096:  "#b784ab",
    8192:  "#a566a0",
    16384: "#934b95",
    32768: "#6d35a0",
    65536: "#4a1a8a",
    131072: "#2d0f5e",
}

fallout_tiles = {}
for i, val in enumerate(classic_tiles.keys()):
    # Scale from dark green #0f2a0f to bright green #4fff4f
    r = int(15 + (79 - 15) * (i / 16))
    g = int(42 + (255 - 42) * (i / 16))
    b = int(15 + (79 - 15) * (i / 16))
    fallout_tiles[val] = f"#{r:02x}{g:02x}{b:02x}"

noir_tiles = {}
for i, val in enumerate(classic_tiles.keys()):
    # Scale from dark grey #444444 to white #ffffff
    c = int(68 + (255 - 68) * (i / 16))
    noir_tiles[val] = f"#{c:02x}{c:02x}{c:02x}"

def print_tiles(tiles):
    for k, v in tiles.items():
        print(f"\t\t\t{k}:\tColor(\"{v}\"),")

print("--- Classic ---")
print_tiles(classic_tiles)
print("--- Fallout ---")
print_tiles(fallout_tiles)
print("--- Noir ---")
print_tiles(noir_tiles)
