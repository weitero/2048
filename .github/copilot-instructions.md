# Copilot Instructions — 2048 (Godot 4)

## Project

A 2048 puzzle game built with Godot 4.3 (GL Compatibility renderer), targeting desktop.
Window is fixed at 540 × 720 px. All UI is constructed programmatically in `_ready()` —
there are no nodes in the `.tscn` files beyond a root node + attached script.

## Running the project

Open `project.godot` in Godot 4.3+, then press **F5** (or use the Run button).
There is no CLI build/test command — testing is done inside the Godot editor.

The best score is persisted to `user://save.cfg` (a `ConfigFile` ini file).
On macOS it lives at `~/Library/Application Support/Godot/app_userdata/2048/save.cfg`.

## Architecture

```
scripts/game.gd   – Root scene. Builds all UI nodes in _ready(), handles keyboard
                    input, and reacts to board signals (score_changed, game_over, game_won).
scripts/board.gd  – Owns the canonical board state (cells: Array[int], 16 values,
                    row-major). Manages Tile nodes as a pure visual layer. Emits signals;
                    game.gd never touches cells directly.
scripts/tile.gd   – Single tile: Panel + Label created in _ready(). Exposes setup(),
                    play_spawn(), play_merge(), slide_to(). All animation via Tween.
```

**Data flow:**
1. `game.gd._unhandled_key_input` → `board.move(direction)`
2. `board.move` runs `_slide_line` on each of the 4 lines, updates `cells`, fires
   `_run_animation` (a coroutine — called without `await` so it runs in the background)
3. After the 0.13 s slide tween, the coroutine resolves merges, spawns a new tile,
   and checks win/loss via `_check_game_state`
4. `score_changed / game_over / game_won` signals → `game.gd` handler methods

## Key conventions

**Layout constants live in each script's `const` block at the top.**
`Board.BOARD_SIZE = 488`, `Board.CELL_SIZE = 107`, `Board.GAP = 12`.
`Tile.CELL_SIZE` must stay in sync with `Board.CELL_SIZE` (both are 107).

**`_slide_line(values: Array[int]) -> Dictionary`** is the core algorithm (in `board.gd`).
It returns `{new_values, score, moves, merges}` with line-local indices.
`_line_positions(direction, line_idx)` maps any direction to an ordered Array[Vector2i]
such that "slide toward index 0" always means movement in `direction`.

**Animation guard:** `_anim_gen: int` increments on every `start_game()`.
`_run_animation` captures `gen` before `await`-ing and bails if it doesn't match on resume.
This prevents a restart mid-animation from operating on freed tile nodes.

**Tile node lifecycle:** `_tile_nodes: Dictionary` maps `Vector2i(col, row) → Tile`.
Only `board.gd` creates/frees Tile nodes. `game.gd` never touches them.
After a move, `_run_animation` rebuilds `_tile_nodes` from scratch into `new_tile_nodes`
before assigning it, so the dict is never mutated while being iterated.

**Score persistence:** `ConfigFile` to `user://save.cfg`, section `"scores"`, key `"best"`.
`_save_best_score` is called only when `_current_score > _best_score` to minimise I/O.

## Input map

Built-in actions `ui_left / ui_right / ui_up / ui_down` handle arrow keys.
Custom action `restart` (R key) is defined in `project.godot [input]`.

## File layout

```
project.godot
icon.svg
scenes/
  game.tscn     – root Control + game.gd
  board.tscn    – Control + board.gd
  tile.tscn     – Control + tile.gd
scripts/
  game.gd
  board.gd
  tile.gd
assets/           (reserved for fonts / theme if added later)
```
