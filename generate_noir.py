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

noir_tiles = {}
# Aggressive curve
colors = [
    "#000000", "#0a0a0a", "#161616", "#242424", 
    "#363636", "#4a4a4a", "#626262", "#7c7c7c", 
    "#999999", "#b5b5b5", "#d4d4d4", "#f4f0ec", 
    "#f6f3f0", "#f8f6f4", "#faf9f7", "#fdfcfb", "#ffffff"
]
for i, val in enumerate(classic_tiles.keys()):
    noir_tiles[val] = colors[i]

def print_tiles(tiles):
    for k, v in tiles.items():
        print(f"\t\t\t{k}:\tColor(\"{v}\"),")

print("--- Noir ---")
print_tiles(noir_tiles)
