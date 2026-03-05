# Tile: visual representation of a single 2048 cell.
# All children (Panel + Label) are created programmatically in _ready().
# Call setup() after add_child() to apply a value and grid position.
class_name Tile
extends Control

# Must stay in sync with Board.CELL_SIZE
const CELL_SIZE := 107

# Classic 2048 color palette
const TILE_COLORS: Dictionary = {
	2:    Color("#eee4da"),
	4:    Color("#ede0c8"),
	8:    Color("#f2b179"),
	16:   Color("#f59563"),
	32:   Color("#f67c5f"),
	64:   Color("#f65e3b"),
	128:  Color("#edcf72"),
	256:  Color("#edcc61"),
	512:  Color("#edc850"),
	1024: Color("#edc53f"),
	2048: Color("#edc22e"),
}

const C_DARK_TEXT  := Color("#776e65")  # used for values 2 and 4
const C_LIGHT_TEXT := Color("#f9f6f2")  # used for 8 and above
const C_UNKNOWN_BG := Color("#3c3a32")  # fallback for values > 2048

var value: int = 0
var grid_pos: Vector2i = Vector2i.ZERO

var _bg_style: StyleBoxFlat
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	size = Vector2(CELL_SIZE, CELL_SIZE)
	pivot_offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)

	_bg_style = StyleBoxFlat.new()
	_bg_style.corner_radius_top_left    = 6
	_bg_style.corner_radius_top_right   = 6
	_bg_style.corner_radius_bottom_left = 6
	_bg_style.corner_radius_bottom_right = 6
	_bg_style.bg_color = C_UNKNOWN_BG

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _bg_style)
	add_child(panel)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	# Apply value if setup() was called before this node entered the tree
	if value != 0:
		_update_visuals()


# Set the tile's numeric value and grid position.
# Safe to call before or after add_child().
func setup(v: int, gpos: Vector2i) -> void:
	value    = v
	grid_pos = gpos
	if _label != null:
		_update_visuals()


func _update_visuals() -> void:
	_bg_style.bg_color = TILE_COLORS.get(value, C_UNKNOWN_BG)
	_label.text = str(value)
	_label.add_theme_color_override("font_color",
		C_DARK_TEXT if value <= 4 else C_LIGHT_TEXT)
	_label.add_theme_font_size_override("font_size", _font_size_for(value))


func _font_size_for(v: int) -> int:
	if v < 100:  return 48
	if v < 1000: return 40
	return 32


# ── Animations ────────────────────────────────────────────────────────────────

# Scale from zero on first appearance
func play_spawn() -> void:
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)


# Brief scale-up pop after a merge
func play_merge() -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.07)
	tw.tween_property(self, "scale", Vector2.ONE, 0.07)


# Smooth slide to a pixel position; returns the Tween so callers can await it
func slide_to(target_pos: Vector2, duration: float = 0.1) -> Tween:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUINT)
	tw.tween_property(self, "position", target_pos, duration)
	return tw
