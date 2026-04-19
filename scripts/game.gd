# Game: root scene — builds the full UI, handles input, and reacts to board signals.
# All UI nodes are created programmatically so layout constants stay in one place.
class_name Game
extends Control

# ── Layout ────────────────────────────────────────────────────────────────────
const WINDOW_W    := 540
const WINDOW_H    := 720
const SIDE_MARGIN := 26   # (WINDOW_W - Board.BOARD_SIZE) / 2 = (540-488)/2
const TOP_MARGIN  := 20
const HEADER_H    := 80
const BOARD_Y     := TOP_MARGIN + HEADER_H + 20  # 120

# ── Color Palettes ────────────────────────────────────────────────────────────
const PALETTE_LIGHT := {
	"bg":          Color("#faf8ef"),
	"title":       Color("#776e65"),
	"subtitle":    Color("#776e65"),
	"hint":        Color("#a09888"),
	"score_bg":    Color("#bbada0"),
	"score_lbl":   Color("#eee4da"),
	"score_val":   Color("#ffffff"),
	"overlay_dim": Color(0.737, 0.706, 0.627, 0.73),
	"overlay_box": Color("#f9f6f2"),
	"btn_normal":  Color("#8f7a66"),
	"btn_hover":   Color("#9f8b77"),
	"btn_pressed": Color("#7f6a56"),
	"btn_text":    Color("#f9f6f2"),
	"overlay_txt": Color("#776e65"),
	"board_bg":    Color("#bbada0"),
	"cell_slot":   Color("#cdc1b4"),
	"toggle_text": Color("#a09888"),
}

const PALETTE_DARK := {
	"bg":          Color("#1a1a2e"),
	"title":       Color("#e8e0d8"),
	"subtitle":    Color("#b0a8a0"),
	"hint":        Color("#706868"),
	"score_bg":    Color("#2a2a42"),
	"score_lbl":   Color("#8080a0"),
	"score_val":   Color("#f0f0f0"),
	"overlay_dim": Color(0.06, 0.06, 0.12, 0.82),
	"overlay_box": Color("#262640"),
	"btn_normal":  Color("#4a4a6e"),
	"btn_hover":   Color("#5a5a80"),
	"btn_pressed": Color("#3a3a5e"),
	"btn_text":    Color("#e8e0d8"),
	"overlay_txt": Color("#e8e0d8"),
	"board_bg":    Color("#2a2a42"),
	"cell_slot":   Color("#363656"),
	"toggle_text": Color("#706868"),
}

# ── Node refs ─────────────────────────────────────────────────────────────────
var _score_label:   Label
var _best_label:    Label
var _overlay:       Control
var _overlay_msg:   Label
var _overlay_btn:       Button
var _keep_playing_btn:  Button
var _board:             Board

# Refs for theme recoloring
var _bg_rect:       ColorRect
var _title_label:   Label
var _sub_label:     Label
var _hint_label:    Label
var _score_box_styles:  Array[StyleBoxFlat] = []
var _score_lbl_labels:  Array[Label] = []   # "SCORE", "BEST" caption labels
var _dim_rect:      ColorRect
var _overlay_box_style: StyleBoxFlat
var _toggle_btn:    Button
var _restart_btn:   Button

# ── Audio ─────────────────────────────────────────────────────────────────────
var _sfx_slide:     AudioStreamPlayer
var _sfx_merge:     AudioStreamPlayer
var _sfx_game_over: AudioStreamPlayer
var _sfx_win:       AudioStreamPlayer

const SAVE_PATH    := "user://save.cfg"
const SAVE_SECTION := "scores"

var _current_score: int  = 0
var _best_score:    int  = 0
var _dark_mode:     bool = false
var _palette:       Dictionary = PALETTE_LIGHT

# ── Touch / swipe ─────────────────────────────────────────────────────────────
const SWIPE_MIN_DIST := 30.0  # minimum px distance to register a swipe
var _touch_start: Vector2 = Vector2.ZERO
var _is_touching: bool = false


func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(270, 360))  # half design resolution
	_best_score = _load_best_score()
	_dark_mode  = _load_dark_mode()
	_palette    = PALETTE_DARK if _dark_mode else PALETTE_LIGHT
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_web_fixes()
	_add_audio()
	_add_background()
	_add_header()
	_add_board()
	_add_footer()
	_add_overlay()
	_apply_palette()
	# Sync best label now that _best_label node exists
	if _best_score > 0:
		_best_label.text = str(_best_score)


func _apply_web_fixes() -> void:
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var js_code := """
		// 1. Prevent Safari swipe-to-scroll without breaking clicks
		document.body.style.overflow = 'hidden';
		document.addEventListener('touchmove', function(e) {
			if (e.target.tagName === 'CANVAS') e.preventDefault();
		}, { passive: false });

		// 2. Foolproof HTML-based audio unlocker for iOS Safari bypassing silent switch
		const btn = document.createElement('button');
		btn.innerHTML = 'Tap to Start';
		btn.style.position = 'fixed';
		btn.style.top = '0'; btn.style.left = '0';
		btn.style.width = '100vw'; btn.style.height = '100vh';
		btn.style.zIndex = '9999';
		btn.style.background = 'rgba(0,0,0,0.85)';
		btn.style.color = 'white';
		btn.style.fontSize = '24px';
		btn.style.border = 'none';
		btn.style.fontFamily = 'sans-serif';
		document.body.appendChild(btn);

		btn.addEventListener('click', () => {
			if (typeof Engine !== 'undefined' && Engine.Audio && Engine.Audio.ctx) {
				Engine.Audio.ctx.resume();
			}
			
			const silentAudio = document.createElement('audio');
			silentAudio.src = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA';
			silentAudio.play().catch(e => {});

			btn.remove();
		});
		"""
		var _res = JavaScriptBridge.eval(js_code)


func _add_audio() -> void:
	_sfx_slide     = _make_sfx_player("res://assets/slide.wav")
	_sfx_merge     = _make_sfx_player("res://assets/merge.wav")
	_sfx_game_over = _make_sfx_player("res://assets/game_over.wav")
	_sfx_win       = _make_sfx_player("res://assets/win.wav")


func _make_sfx_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = "Master"
	add_child(player)
	return player


# ── UI construction ───────────────────────────────────────────────────────────

func _add_background() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)


func _add_header() -> void:
	var header := Control.new()
	header.position = Vector2(SIDE_MARGIN, TOP_MARGIN)
	header.size = Vector2(Board.BOARD_SIZE, HEADER_H)
	add_child(header)

	# "2048" title — left side
	_title_label = Label.new()
	_title_label.text = "2048"
	_title_label.size = Vector2(180, HEADER_H)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	header.add_child(_title_label)

	# Score boxes — right side, vertically centred
	const SCORES_W := 111 * 2 + 8  # two 111 px boxes + 8 px gap = 230
	var scores := HBoxContainer.new()
	scores.position = Vector2(Board.BOARD_SIZE - SCORES_W, (HEADER_H - 58) / 2.0)
	scores.size = Vector2(SCORES_W, 58)
	scores.add_theme_constant_override("separation", 8)
	header.add_child(scores)

	var score_box := _make_score_box("SCORE")
	_score_label = score_box.get_node("VBox/Value")
	scores.add_child(score_box)

	var best_box := _make_score_box("BEST")
	_best_label = best_box.get_node("VBox/Value")
	scores.add_child(best_box)


func _make_score_box(title: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(111, 58)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	_score_box_styles.append(style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl)
	_score_lbl_labels.append(lbl)

	var val := Label.new()
	val.name = "Value"
	val.text = "0"
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 22)
	vbox.add_child(val)

	return panel


func _add_board() -> void:
	_board = load("res://scenes/board.tscn").instantiate() as Board
	_board.position = Vector2(SIDE_MARGIN, BOARD_Y)
	add_child(_board)

	_board.tiles_moved.connect(_on_tiles_moved)
	_board.score_changed.connect(_on_score_changed)
	_board.game_over.connect(_on_game_over)
	_board.game_won.connect(_on_game_won)
	_board.start_game()


func _add_footer() -> void:
	var board_bottom := BOARD_Y + Board.BOARD_SIZE

	_sub_label = Label.new()
	_sub_label.text = "Join the tiles, get to 2048!"
	_sub_label.position = Vector2(SIDE_MARGIN, board_bottom + 16)
	_sub_label.add_theme_font_size_override("font_size", 16)
	add_child(_sub_label)

	_hint_label = Label.new()
	_hint_label.text = "Swipe or arrow keys to move"
	_hint_label.position = Vector2(SIDE_MARGIN, board_bottom + 42)
	_hint_label.add_theme_font_size_override("font_size", 14)
	add_child(_hint_label)

	# Dark/light mode toggle — right side of footer
	_toggle_btn = Button.new()
	_toggle_btn.text = "Light" if _dark_mode else "Dark"
	_toggle_btn.custom_minimum_size = Vector2(52, 32)
	_toggle_btn.position = Vector2(SIDE_MARGIN + Board.BOARD_SIZE - 52, board_bottom + 16)
	_toggle_btn.add_theme_font_size_override("font_size", 16)
	# Flat, borderless style
	for state: String in ["normal", "hover", "pressed"]:
		_toggle_btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(_on_toggle_dark_mode)
	add_child(_toggle_btn)

	# Restart button — left of toggle
	_restart_btn = Button.new()
	_restart_btn.text = "New"
	_restart_btn.custom_minimum_size = Vector2(42, 32)
	_restart_btn.position = Vector2(SIDE_MARGIN + Board.BOARD_SIZE - 52 - 8 - 42, board_bottom + 16)
	_restart_btn.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "hover", "pressed"]:
		_restart_btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_restart_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_restart_btn.focus_mode = Control.FOCUS_NONE
	_restart_btn.pressed.connect(_on_restart_pressed)
	add_child(_restart_btn)


func _add_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 10
	_overlay.visible = false
	add_child(_overlay)

	# Semi-transparent dim layer
	_dim_rect = ColorRect.new()
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_dim_rect)

	# Centred message box
	const BOX_SIZE := Vector2(300, 180)
	var box := Panel.new()
	box.size = BOX_SIZE
	box.position = (Vector2(WINDOW_W, WINDOW_H) - BOX_SIZE) / 2.0

	_overlay_box_style = StyleBoxFlat.new()
	_overlay_box_style.corner_radius_top_left     = 8
	_overlay_box_style.corner_radius_top_right    = 8
	_overlay_box_style.corner_radius_bottom_left  = 8
	_overlay_box_style.corner_radius_bottom_right = 8
	box.add_theme_stylebox_override("panel", _overlay_box_style)
	_overlay.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	box.add_child(vbox)

	_overlay_msg = Label.new()
	_overlay_msg.text = "Game Over!"
	_overlay_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_msg.add_theme_font_size_override("font_size", 36)
	vbox.add_child(_overlay_msg)

	# Button row — holds "Keep Playing" (win only) and "Try Again"
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_keep_playing_btn = Button.new()
	_keep_playing_btn.text = "Keep Playing"
	_keep_playing_btn.custom_minimum_size = Vector2(130, 46)
	_keep_playing_btn.pressed.connect(_on_keep_playing_pressed)
	_keep_playing_btn.visible = false
	btn_row.add_child(_keep_playing_btn)

	_overlay_btn = Button.new()
	_overlay_btn.text = "Try Again"
	_overlay_btn.custom_minimum_size = Vector2(130, 46)
	_overlay_btn.pressed.connect(_on_restart_pressed)
	btn_row.add_child(_overlay_btn)


func _style_button(btn: Button) -> void:
	var p := _palette
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		match state:
			"hover":    s.bg_color = p.btn_hover
			"pressed":  s.bg_color = p.btn_pressed
			_:          s.bg_color = p.btn_normal
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override(state, s)
	# Remove focus highlight ring
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(color_name, p.btn_text)
	btn.add_theme_font_size_override("font_size", 18)


# ── Theme / Palette ───────────────────────────────────────────────────────────

func _apply_palette() -> void:
	var p := _palette

	# Background
	_bg_rect.color = p.bg

	# Header
	_title_label.add_theme_color_override("font_color", p.title)

	# Score boxes
	for style in _score_box_styles:
		style.bg_color = p.score_bg
	for lbl in _score_lbl_labels:
		lbl.add_theme_color_override("font_color", p.score_lbl)
	_score_label.add_theme_color_override("font_color", p.score_val)
	_best_label.add_theme_color_override("font_color", p.score_val)

	# Footer
	_sub_label.add_theme_color_override("font_color", p.subtitle)
	_hint_label.add_theme_color_override("font_color", p.hint)

	# Toggle & restart buttons
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_toggle_btn.add_theme_color_override(color_name, p.toggle_text)
		_restart_btn.add_theme_color_override(color_name, p.toggle_text)

	# Overlay
	_dim_rect.color = p.overlay_dim
	_overlay_box_style.bg_color = p.overlay_box
	_overlay_msg.add_theme_color_override("font_color", p.overlay_txt)

	# Buttons (restyle with current palette)
	_style_button(_overlay_btn)
	_style_button(_keep_playing_btn)

	# Board
	_board.apply_colors(p.board_bg, p.cell_slot)


func _on_toggle_dark_mode() -> void:
	_dark_mode = not _dark_mode
	_palette   = PALETTE_DARK if _dark_mode else PALETTE_LIGHT
	_toggle_btn.text = "Light" if _dark_mode else "Dark"
	_apply_palette()
	_save_dark_mode(_dark_mode)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if _overlay.visible:
		return
	if event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("ui_right"):
		_board.move(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_left"):
		_board.move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_up"):
		_board.move(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_board.move(Vector2i.DOWN)


func _unhandled_input(event: InputEvent) -> void:
	# Handle touch events (native mobile)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_start = touch.position
			_is_touching = true
		elif _is_touching:
			_is_touching = false
			_try_swipe(touch.position)
		return

	# Handle mouse-button events (web exports deliver touch as mouse)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_touch_start = mb.position
			_is_touching = true
		elif _is_touching:
			_is_touching = false
			_try_swipe(mb.position)


func _try_swipe(end_pos: Vector2) -> void:
	if _overlay.visible:
		return
	var delta := end_pos - _touch_start
	if delta.length() < SWIPE_MIN_DIST:
		return
	# Determine primary axis
	if absf(delta.x) > absf(delta.y):
		_board.move(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
	else:
		_board.move(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)
# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_tiles_moved() -> void:
	_sfx_slide.play()


func _on_score_changed(delta: int) -> void:
	_current_score += delta
	_score_label.text = str(_current_score)
	_show_score_popup(delta)
	_sfx_merge.play()
	if _current_score > _best_score:
		_best_score = _current_score
		_best_label.text = str(_best_score)
		_save_best_score(_best_score)


func _show_score_popup(delta: int) -> void:
	var popup := Label.new()
	popup.text = "+" + str(delta)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 20)
	popup.add_theme_color_override("font_color", _palette.title)

	# Position above the score box
	var score_global := _score_label.global_position
	popup.position = Vector2(score_global.x, score_global.y - 10)
	popup.size = Vector2(_score_label.size.x, 28)
	add_child(popup)

	# Float up and fade out
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y - 30, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tw.tween_property(popup, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(popup.queue_free)


func _on_game_over() -> void:
	_overlay_msg.text = "Game Over!"
	_keep_playing_btn.visible = false
	_overlay.visible = true
	_overlay_btn.grab_focus()
	_sfx_game_over.play()


func _on_game_won() -> void:
	_overlay_msg.text = "You Win!"
	_keep_playing_btn.visible = true
	_overlay.visible = true
	_keep_playing_btn.grab_focus()
	_sfx_win.play()


func _on_keep_playing_pressed() -> void:
	_overlay.visible = false


func _on_restart_pressed() -> void:
	_restart()


func _restart() -> void:
	_overlay.visible = false
	_current_score = 0
	_score_label.text = "0"
	_board.start_game()


# ── Persistence ───────────────────────────────────────────────────────────────

func _load_best_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value(SAVE_SECTION, "best", 0))


func _save_best_score(score: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # OK if file doesn't exist yet; cfg stays empty
	cfg.set_value(SAVE_SECTION, "best", score)
	cfg.save(SAVE_PATH)


func _load_dark_mode() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		# No saved preference — follow system setting
		return DisplayServer.is_dark_mode()
	if cfg.has_section_key("settings", "dark_mode"):
		return bool(cfg.get_value("settings", "dark_mode", false))
	# Key not saved yet — follow system setting
	return DisplayServer.is_dark_mode()


func _save_dark_mode(dark: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "dark_mode", dark)
	cfg.save(SAVE_PATH)
