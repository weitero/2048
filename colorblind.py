tiles = {
    2: "#03045e",
    4: "#023e8a",
    8: "#0077b6",
    16: "#0096c7",
    32: "#00b4d8",
    64: "#48cae4",
    128: "#90e0ef",
    256: "#caf0f8",
    512: "#ffea00",
    1024: "#ffc300",
    2048: "#ffaa00",
    4096: "#ff9500",
    8192: "#ff7b00",
    16384: "#ff6000",
    32768: "#ff4800",
    65536: "#ff2a00",
    131072: "#ffffff"
}

print('\t"Colorblind": {')
print('\t\t"bg":          Color("#2b2d42"),')
print('\t\t"title":       Color("#edf2f4"),')
print('\t\t"subtitle":    Color("#8d99ae"),')
print('\t\t"hint":        Color("#8d99ae"),')
print('\t\t"score_bg":    Color("#1a1b26"),')
print('\t\t"score_lbl":   Color("#8d99ae"),')
print('\t\t"score_val":   Color("#edf2f4"),')
print('\t\t"overlay_dim": Color(0.1, 0.1, 0.1, 0.8),')
print('\t\t"overlay_box": Color("#2b2d42"),')
print('\t\t"btn_normal":  Color("#1a1b26"),')
print('\t\t"btn_hover":   Color("#8d99ae"),')
print('\t\t"btn_pressed": Color("#0d0e15"),')
print('\t\t"btn_text":    Color("#edf2f4"),')
print('\t\t"overlay_txt": Color("#edf2f4"),')
print('\t\t"board_bg":    Color("#1a1b26"),')
print('\t\t"cell_slot":   Color("#2b2d42"),')
print('\t\t"toggle_text": Color("#edf2f4"),')
print('\t\t"tiles": {')
for k, v in tiles.items():
    print(f'\t\t\t{k}:      Color("{v}"),')
print('\t\t},')
print('\t\t"dark_text":  Color("#ffffff"),')
print('\t\t"light_text": Color("#000000"),')
print('\t\t"unknown_bg": Color("#2b2d42"),')
print('\t\t"light_text_threshold": 128,')
print('\t}')
