# Board: renders the 4×4 grid background and manages tile nodes.
# Holds the authoritative board state in `cells` (Array[int], row-major).
# Tile nodes are a pure visual layer driven by the data in `cells`.
class_name Board
extends Control

const CELL_SIZE  := 107   # px — must match Tile.CELL_SIZE
const GAP        := 12    # px between cells (and around edges)
const BOARD_SIZE := 4 * CELL_SIZE + 5 * GAP  # 488 px

const C_BOARD_BG  := Color("#bbada0")
const C_CELL_SLOT := Color("#cdc1b4")

signal score_changed(delta: int)
signal tiles_moved
signal game_over
signal game_won

# Flat row-major array: index = row * 4 + col, 0 means empty
var cells: Array[int] = []

# Maps Vector2i(col, row) → Tile node
var _tile_nodes:     Dictionary = {}
var _tile_scene:     PackedScene
var _is_animating:   bool = false
var _game_won_fired: bool = false
var _anim_gen:       int  = 0  # incremented on restart to cancel stale coroutines

var _bg_style:       StyleBoxFlat
var _slot_styles:    Array[StyleBoxFlat] = []
var _current_theme_dict: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(BOARD_SIZE, BOARD_SIZE)
	size = Vector2(BOARD_SIZE, BOARD_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tile_scene = load("res://scenes/tile.tscn")

	cells.resize(16)
	cells.fill(0)

	_build_background()
	_build_cell_slots()


func _build_background() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = C_BOARD_BG
	_bg_style.corner_radius_top_left     = 8
	_bg_style.corner_radius_top_right    = 8
	_bg_style.corner_radius_bottom_left  = 8
	_bg_style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", _bg_style)
	add_child(bg)


func _build_cell_slots() -> void:
	var slot_style_proto := StyleBoxFlat.new()
	slot_style_proto.bg_color = C_CELL_SLOT
	slot_style_proto.corner_radius_top_left     = 6
	slot_style_proto.corner_radius_top_right    = 6
	slot_style_proto.corner_radius_bottom_left  = 6
	slot_style_proto.corner_radius_bottom_right = 6

	for row in 4:
		for col in 4:
			var slot := Panel.new()
			slot.position = _cell_pixel_pos(Vector2i(col, row))
			slot.size = Vector2(CELL_SIZE, CELL_SIZE)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var s := slot_style_proto.duplicate() as StyleBoxFlat
			slot.add_theme_stylebox_override("panel", s)
			_slot_styles.append(s)
			add_child(slot)


# Returns the top-left pixel position of a grid cell
func _cell_pixel_pos(gpos: Vector2i) -> Vector2:
	return Vector2(
		GAP + gpos.x * (CELL_SIZE + GAP),
		GAP + gpos.y * (CELL_SIZE + GAP)
	)


# ── Public API ────────────────────────────────────────────────────────────────

# Update board and cell slot colors, and push to all tiles
func apply_theme(theme_dict: Dictionary) -> void:
	_current_theme_dict = theme_dict
	if _bg_style:
		_bg_style.bg_color = theme_dict.get("board_bg", C_BOARD_BG)
	for s in _slot_styles:
		s.bg_color = theme_dict.get("cell_slot", C_CELL_SLOT)
	for tile: Tile in _tile_nodes.values():
		tile.apply_theme(theme_dict)

# Reset the board and spawn two starting tiles
func start_game() -> void:
	_anim_gen      += 1
	_is_animating   = false
	_game_won_fired = false
	_clear_tiles()
	cells.fill(0)
	_spawn_tile()
	_spawn_tile()


# Attempt to slide all tiles in `direction`.  No-op if board unchanged or
# an animation is already running.
func move(direction: Vector2i) -> void:
	if _is_animating:
		return

	var all_moves:  Array = []
	var all_merges: Array = []
	var total_score := 0
	var board_changed := false

	for line_idx in 4:
		var positions := _line_positions(direction, line_idx)

		# Read current values in line order
		var values: Array[int] = []
		for pos in positions:
			values.append(cells[pos.y * 4 + pos.x])

		var result := _slide_line(values)
		if result.moves.is_empty() and result.merges.is_empty():
			continue

		board_changed  = true
		total_score   += result.score

		# Write the new values back (clear first to avoid overlap confusion)
		for pos in positions:
			cells[pos.y * 4 + pos.x] = 0
		for i in 4:
			cells[positions[i].y * 4 + positions[i].x] = result.new_values[i]

		# Translate line-local indices → board positions for the animator
		for m in result.moves:
			all_moves.append({"from": positions[m.from_idx], "to": positions[m.to_idx]})
		for mg in result.merges:
			all_merges.append({
				"from_a": positions[mg.from_a_idx],
				"from_b": positions[mg.from_b_idx],
				"to":     positions[mg.to_idx],
				"value":  mg.value,
			})

	if not board_changed:
		return

	tiles_moved.emit()

	if total_score > 0:
		score_changed.emit(total_score)

	_is_animating = true
	_run_animation(all_moves, all_merges)  # coroutine; runs without await


# True when there is at least one empty cell or one pair of adjacent equal tiles
func has_moves() -> bool:
	for v in cells:
		if v == 0:
			return true
	for row in 4:
		for col in 4:
			var v := cells[row * 4 + col]
			if col < 3 and cells[row * 4 + col + 1] == v:
				return true
			if row < 3 and cells[(row + 1) * 4 + col] == v:
				return true
	return false


# ── Slide algorithm ───────────────────────────────────────────────────────────

# Returns grid positions for one line ordered so that index-0 is the
# destination edge for a left-slide (i.e. the direction of movement).
func _line_positions(direction: Vector2i, line_idx: int) -> Array[Vector2i]:
	var pos: Array[Vector2i] = []
	match direction:
		Vector2i.LEFT:
			for col in 4:               pos.append(Vector2i(col, line_idx))
		Vector2i.RIGHT:
			for col in range(3, -1, -1): pos.append(Vector2i(col, line_idx))
		Vector2i.UP:
			for row in 4:               pos.append(Vector2i(line_idx, row))
		Vector2i.DOWN:
			for row in range(3, -1, -1): pos.append(Vector2i(line_idx, row))
	return pos


# Slide a 4-element line toward index 0 and merge equal adjacent pairs.
# Each tile can participate in at most one merge per move.
#
# Returns a Dictionary:
#   new_values : Array[int]  – resulting 4 values
#   score      : int         – points earned by merges in this line
#   moves      : Array       – [{from_idx, to_idx}]  simple (non-merge) moves
#   merges     : Array       – [{from_a_idx, from_b_idx, to_idx, value}]
func _slide_line(values: Array[int]) -> Dictionary:
	var score  := 0
	var moves:  Array = []
	var merges: Array = []

	# Compact: remove zeros, preserve original indices
	var nz: Array = []
	for i in 4:
		if values[i] != 0:
			nz.append({"v": values[i], "idx": i})

	# Merge adjacent equal pairs (left-to-right, once per tile)
	var merged: Array = []
	var i := 0
	while i < nz.size():
		if i + 1 < nz.size() and nz[i].v == nz[i + 1].v:
			var new_v: int = nz[i].v * 2
			score += new_v
			merged.append({"v": new_v, "a": nz[i].idx, "b": nz[i + 1].idx})
			i += 2
		else:
			merged.append({"v": nz[i].v, "a": nz[i].idx, "b": -1})
			i += 1

	# Build output (new_values defaults to 0 for empty tail slots)
	var new_values: Array[int] = [0, 0, 0, 0]
	for dest in merged.size():
		var e = merged[dest]
		new_values[dest] = e.v
		if e.b != -1:
			merges.append({"from_a_idx": e.a, "from_b_idx": e.b, "to_idx": dest, "value": e.v})
		elif e.a != dest:
			moves.append({"from_idx": e.a, "to_idx": dest})

	return {"new_values": new_values, "score": score, "moves": moves, "merges": merges}


# ── Animation ─────────────────────────────────────────────────────────────────

# Coroutine: slides tiles, awaits completion, resolves merges, spawns, checks state.
func _run_animation(all_moves: Array, all_merges: Array) -> void:
	var gen := _anim_gen  # capture; if start_game() fires during the await, gen won't match
	var new_tile_nodes: Dictionary = {}
	var losers:  Array[Tile] = []
	var winners: Array       = []  # [{tile, value, gpos}]

	# Build a set of every source position involved in a move or merge
	var moved_srcs: Dictionary = {}
	for m  in all_moves:  moved_srcs[m.from]   = true
	for mg in all_merges: moved_srcs[mg.from_a] = true; moved_srcs[mg.from_b] = true

	# Tiles not in any move stay at their current position
	for pos in _tile_nodes:
		if pos not in moved_srcs:
			new_tile_nodes[pos] = _tile_nodes[pos]

	# Simple slides
	var tweens: Array[Tween] = []
	for m in all_moves:
		var tile: Tile = _tile_nodes[m.from]
		tile.grid_pos = m.to
		tweens.append(tile.slide_to(_cell_pixel_pos(m.to)))
		new_tile_nodes[m.to] = tile

	# Merge slides: both tiles travel to the destination
	for mg in all_merges:
		var winner: Tile = _tile_nodes[mg.from_a]
		var loser:  Tile = _tile_nodes[mg.from_b]
		var dest_px := _cell_pixel_pos(mg.to)
		winner.grid_pos = mg.to
		tweens.append(winner.slide_to(dest_px))
		tweens.append(loser.slide_to(dest_px))
		losers.append(loser)
		winners.append({"tile": winner, "value": mg.value, "gpos": mg.to})
		new_tile_nodes[mg.to] = winner

	_tile_nodes = new_tile_nodes

	# Wait for all slide tweens to finish
	if not tweens.is_empty():
		await tweens.back().finished
	if not is_inside_tree() or _anim_gen != gen:
		_is_animating = false
		return

	# Resolve merges: free losers, update winners, play pop
	for loser in losers:
		loser.queue_free()
	for w in winners:
		var t: Tile = w.tile
		t.setup(w.value, w.gpos)
		t.play_merge()

	_spawn_tile()
	_check_game_state()
	_is_animating = false


func _spawn_tile() -> void:
	var empty: Array[Vector2i] = []
	for row in 4:
		for col in 4:
			if cells[row * 4 + col] == 0:
				empty.append(Vector2i(col, row))
	if empty.is_empty():
		return

	var pos: Vector2i = empty.pick_random()
	var val           := 4 if randf() < 0.1 else 2

	cells[pos.y * 4 + pos.x] = val

	var tile: Tile = _tile_scene.instantiate()
	tile.position = _cell_pixel_pos(pos)
	add_child(tile)
	if not _current_theme_dict.is_empty():
		tile.apply_theme(_current_theme_dict)
	tile.setup(val, pos)
	tile.play_spawn()
	_tile_nodes[pos] = tile


func _clear_tiles() -> void:
	for tile: Node in _tile_nodes.values():
		tile.queue_free()
	_tile_nodes.clear()


func _check_game_state() -> void:
	# Win check (fires once per game)
	if not _game_won_fired:
		for v in cells:
			if v >= 2048:
				_game_won_fired = true
				game_won.emit()
				return
	# Loss check
	if not has_moves():
		game_over.emit()
