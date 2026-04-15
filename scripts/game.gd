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

# ── Colors ────────────────────────────────────────────────────────────────────
const C_BG          := Color("#faf8ef")
const C_TITLE       := Color("#776e65")
const C_SUBTITLE    := Color("#776e65")
const C_HINT        := Color("#a09888")
const C_SCORE_BG    := Color("#bbada0")
const C_SCORE_LBL   := Color("#eee4da")
const C_SCORE_VAL   := Color("#ffffff")
const C_OVERLAY_DIM := Color(0.737, 0.706, 0.627, 0.73)  # #bbada0 @ 73 %
const C_OVERLAY_BOX := Color("#f9f6f2")
const C_BTN_NORMAL  := Color("#8f7a66")
const C_BTN_HOVER   := Color("#9f8b77")
const C_BTN_PRESSED := Color("#7f6a56")
const C_OVERLAY_TXT := Color("#776e65")

# ── Node refs ─────────────────────────────────────────────────────────────────
var _score_label:   Label
var _best_label:    Label
var _overlay:       Control
var _overlay_msg:   Label
var _overlay_btn:       Button
var _keep_playing_btn:  Button
var _board:             Board

# ── Audio ─────────────────────────────────────────────────────────────────────
var _sfx_slide:     AudioStreamPlayer
var _sfx_merge:     AudioStreamPlayer
var _sfx_game_over: AudioStreamPlayer
var _sfx_win:       AudioStreamPlayer

const SAVE_PATH    := "user://save.cfg"
const SAVE_SECTION := "scores"

var _current_score: int = 0
var _best_score:    int = 0


func _ready() -> void:
	_best_score = _load_best_score()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#_apply_font_theme()
	_add_audio()
	_add_background()
	_add_header()
	_add_board()
	_add_footer()
	_add_overlay()
	# Sync best label now that _best_label node exists
	if _best_score > 0:
		_best_label.text = str(_best_score)


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
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	add_child(bg)


func _add_header() -> void:
	var header := Control.new()
	header.position = Vector2(SIDE_MARGIN, TOP_MARGIN)
	header.size = Vector2(Board.BOARD_SIZE, HEADER_H)
	add_child(header)

	# "2048" title — left side
	var title := Label.new()
	title.text = "2048"
	title.size = Vector2(180, HEADER_H)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", C_TITLE)
	header.add_child(title)

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
	style.bg_color = C_SCORE_BG
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

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
	lbl.add_theme_color_override("font_color", C_SCORE_LBL)
	vbox.add_child(lbl)

	var val := Label.new()
	val.name = "Value"
	val.text = "0"
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 22)
	val.add_theme_color_override("font_color", C_SCORE_VAL)
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

	var sub := Label.new()
	sub.text = "Join the tiles, get to 2048!"
	sub.position = Vector2(SIDE_MARGIN, board_bottom + 16)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", C_SUBTITLE)
	add_child(sub)

	var hint := Label.new()
	hint.text = "← → ↑ ↓  to move  ·  R  to restart"
	hint.position = Vector2(SIDE_MARGIN, board_bottom + 42)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", C_HINT)
	add_child(hint)


func _add_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 10
	_overlay.visible = false
	add_child(_overlay)

	# Semi-transparent dim layer
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = C_OVERLAY_DIM
	_overlay.add_child(dim)

	# Centred message box
	const BOX_SIZE := Vector2(300, 180)
	var box := Panel.new()
	box.size = BOX_SIZE
	box.position = (Vector2(WINDOW_W, WINDOW_H) - BOX_SIZE) / 2.0

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = C_OVERLAY_BOX
	box_style.corner_radius_top_left     = 8
	box_style.corner_radius_top_right    = 8
	box_style.corner_radius_bottom_left  = 8
	box_style.corner_radius_bottom_right = 8
	box.add_theme_stylebox_override("panel", box_style)
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
	_overlay_msg.add_theme_color_override("font_color", C_OVERLAY_TXT)
	vbox.add_child(_overlay_msg)

	# Button row — holds "Keep Playing" (win only) and "Try Again"
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_keep_playing_btn = Button.new()
	_keep_playing_btn.text = "Keep Playing"
	_keep_playing_btn.custom_minimum_size = Vector2(130, 46)
	_style_button(_keep_playing_btn)
	_keep_playing_btn.pressed.connect(_on_keep_playing_pressed)
	_keep_playing_btn.visible = false
	btn_row.add_child(_keep_playing_btn)

	_overlay_btn = Button.new()
	_overlay_btn.text = "Try Again"
	_overlay_btn.custom_minimum_size = Vector2(130, 46)
	_style_button(_overlay_btn)
	_overlay_btn.pressed.connect(_on_restart_pressed)
	btn_row.add_child(_overlay_btn)


func _style_button(btn: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		match state:
			"hover":    s.bg_color = C_BTN_HOVER
			"pressed":  s.bg_color = C_BTN_PRESSED
			_:          s.bg_color = C_BTN_NORMAL
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override(state, s)
	# Remove focus highlight ring
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(color_name, Color("#f9f6f2"))
	btn.add_theme_font_size_override("font_size", 18)


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
	popup.add_theme_color_override("font_color", C_TITLE)

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
