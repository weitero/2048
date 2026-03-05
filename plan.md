# 2048 Game — Godot 4 Development Plan

## Overview

Build a classic 2048 puzzle game using Godot 4. The player slides tiles on a 4×4 grid using arrow keys; tiles with equal values merge. The goal is to reach a tile with value 2048. Platform: Desktop (keyboard input).

## Architecture

```
res://
├── project.godot
├── scenes/
│   ├── game.tscn          # Root scene: wires everything together
│   ├── board.tscn         # 4×4 grid container + board logic
│   └── tile.tscn          # Single tile (label + background + animations)
├── scripts/
│   ├── game.gd            # Top-level: input, game state machine, restart
│   ├── board.gd           # Core logic: move, merge, spawn, win/lose check
│   └── tile.gd            # Tile visuals, color map, slide/pop animations
└── assets/
    └── theme.tres         # UI theme (font, colors)
```

**Data model:** The board state is a flat `Array[int]` of 16 values (0 = empty). Tile nodes are managed separately in a Dictionary keyed by grid position `Vector2i`.

**Scene tree:**
```
Game (Node)
└── CanvasLayer
    ├── VBoxContainer
    │   ├── HBoxContainer        # Score + Best score labels
    │   └── Board (GridContainer / Node2D)
    │       └── Tile × N        # Instantiated at runtime
    └── GameOverlay (Control)   # Win / Game Over panel
```

## Implementation Todos

### Phase 1 — Project Setup
- [ ] Initialize Godot 4 project (`project.godot`, window size 540×720)
- [ ] Create directory structure (scenes/, scripts/, assets/)
- [ ] Set up input map: `ui_left`, `ui_right`, `ui_up`, `ui_down` (already built-in), `restart` → R key

### Phase 2 — Core Board Logic (`board.gd`)
- [ ] Represent board as `var cells: Array[int]` (size 16, row-major)
- [ ] `move(direction: Vector2i) -> bool` — slide & merge in given direction, return true if board changed
- [ ] `spawn_tile()` — place a 2 (90%) or 4 (10%) in a random empty cell
- [ ] `has_moves() -> bool` — check for empty cells or adjacent equal values
- [ ] `get_score() -> int` — sum of all merge values in a move
- [ ] Signals: `tile_moved`, `tile_merged`, `tile_spawned`, `game_won`, `game_over`

### Phase 3 — Tile Scene (`tile.tscn` / `tile.gd`)
- [ ] Panel + Label inside a fixed-size Control node (112×112 px)
- [ ] `set_value(v: int)` — updates label text and background color from a color map
- [ ] Slide animation: `Tween` moving the tile's position over ~100 ms
- [ ] Merge pop animation: brief scale-up then return to normal
- [ ] Spawn animation: scale from 0 to 1 on appear

### Phase 4 — Game Scene (`game.gd`)
- [ ] Instantiate Board, connect signals to UI update methods
- [ ] `_unhandled_key_input` — map arrow keys → `board.move()`, R → restart
- [ ] Update score label; track and persist best score using `ConfigFile` to `user://save.cfg`
- [ ] Show/hide GameOverlay on `game_won` / `game_over` signals
- [ ] `restart()` — reset board data, free all tile nodes, spawn 2 starting tiles

### Phase 5 — Visuals & Polish
- [ ] Tile color map (value → Color): 2=`#eee4da`, 4=`#ede0c8`, 8=`#f2b179`, … 2048=`#edc22e`
- [ ] Board background with rounded cell slots visible beneath tiles
- [ ] Score panel styled to match classic 2048 look
- [ ] Font: a clean sans-serif (Godot default or bundled `.ttf`)

### Phase 6 — Testing & Wrap-up
- [ ] Manual test: all four move directions, merges, double-merge prevention in one move
- [ ] Edge case: full board with no moves triggers game-over correctly
- [ ] Edge case: same value not merged twice in one swipe
- [ ] Add `.github/copilot-instructions.md` describing project conventions

## Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| Board state | `Array[int]` (not nodes) | Simplifies logic; nodes are just a view |
| Tile movement | `Tween` (not AnimationPlayer) | Less setup, easy to chain |
| Best score | `ConfigFile` | Built-in Godot persistence, no dependencies |
| Merge rule | Standard: each tile merges at most once per move | Matches official 2048 rules |

## Merge Algorithm (per row/column)

```
function slide_and_merge(line: Array[int]) -> Array[int]:
    # 1. Compact: remove zeros, shift values to front
    # 2. Merge: scan left-to-right, merge equal adjacent pairs (mark merged)
    # 3. Compact again: remove zeros left by merges
    # 4. Pad with zeros to length 4
```

The four directions are handled by rotating/transposing the board, applying the left-slide algorithm, then rotating back.
