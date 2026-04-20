# Tile: visual representation of a single 2048 cell.
# All children (Panel + Label) are created programmatically in _ready().
# Call setup() after add_child() to apply a value and grid position.
class_name Tile
extends Control

# Must stay in sync with Board.CELL_SIZE
const CELL_SIZE := 107

var _theme_tiles: Dictionary = {}
var _theme_dark_text: Color = Color.WHITE
var _theme_light_text: Color = Color.WHITE
var _theme_unknown_bg: Color = Color.BLACK
var _theme_light_text_threshold: int = 4

var value: int = 0
var grid_pos: Vector2i = Vector2i.ZERO

var _bg_style: StyleBoxFlat
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	size = Vector2(CELL_SIZE, CELL_SIZE)
	pivot_offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg_style = StyleBoxFlat.new()
	_bg_style.corner_radius_top_left    = 6
	_bg_style.corner_radius_top_right   = 6
	_bg_style.corner_radius_bottom_left = 6
	_bg_style.corner_radius_bottom_right = 6
	_bg_style.bg_color = _theme_unknown_bg

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _bg_style)
	add_child(panel)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func apply_theme(theme_dict: Dictionary) -> void:
	_theme_tiles = theme_dict.get("tiles", {})
	_theme_dark_text = theme_dict.get("dark_text", Color.WHITE)
	_theme_light_text = theme_dict.get("light_text", Color.WHITE)
	_theme_unknown_bg = theme_dict.get("unknown_bg", Color.BLACK)
	_theme_light_text_threshold = theme_dict.get("light_text_threshold", 4)
	if _label != null:
		_update_visuals()


func _update_visuals() -> void:
	_bg_style.bg_color = _theme_tiles.get(value, _theme_unknown_bg)
	_label.text = str(value)
	_label.add_theme_color_override("font_color",
		_theme_dark_text if value <= _theme_light_text_threshold else _theme_light_text)
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
