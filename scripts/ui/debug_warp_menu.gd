extends CanvasLayer
## Debug warp menu for quickly teleporting to any screen.

const DESTINATIONS: Array[Dictionary] = [
	{"name": "START", "screen": Vector2i(7, 7), "tile": Vector2i(7, 5)},
	{"name": "MERCHANT", "screen": Vector2i(15, 6), "tile": Vector2i(4, 4)},
	{"name": "OLD MAN CAVE", "screen": Vector2i(7, 7), "tile": Vector2i(4, 1)},
	{"name": "WHITE SWORD", "screen": Vector2i(10, 0), "tile": Vector2i(2, 1)},
	{"name": "OCTOROKS", "screen": Vector2i(7, 6), "tile": Vector2i(7, 5)},
	{"name": "OCTOROKS x2", "screen": Vector2i(7, 5), "tile": Vector2i(7, 5)},
	{"name": "RED TEKTITES", "screen": Vector2i(6, 7), "tile": Vector2i(7, 5)},
	{"name": "BLUE TEKTITES", "screen": Vector2i(9, 7), "tile": Vector2i(7, 5)},
	{"name": "GHINIS", "screen": Vector2i(0, 2), "tile": Vector2i(7, 5)},
	{"name": "RED LEEVERS", "screen": Vector2i(11, 7), "tile": Vector2i(7, 5)},
	{"name": "BLUE LEEVERS", "screen": Vector2i(13, 7), "tile": Vector2i(7, 5)},
	{"name": "PEAHATS", "screen": Vector2i(5, 7), "tile": Vector2i(7, 5)},
	{"name": "RED MOBLINS", "screen": Vector2i(8, 5), "tile": Vector2i(7, 5)},
	{"name": "BLUE MOBLINS", "screen": Vector2i(10, 5), "tile": Vector2i(7, 5)},
	{"name": "ARMOS", "screen": Vector2i(2, 2), "tile": Vector2i(7, 5)},
	{"name": "ROCKS", "screen": Vector2i(5, 1), "tile": Vector2i(7, 5)},
]

const LINE_HEIGHT := 12
const VISIBLE_ROWS := 12

var labels: Array[Label] = []
var title_label: Label
var bg: ColorRect
var cursor_index := 0
var scroll_offset := 0
var is_open := false

# Custom coordinate entry mode
var custom_mode := false
var custom_x := 7
var custom_y := 7
var custom_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.size = Vector2(256, 232)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "WARP MENU  0=CLOSE"
	title_label.position = Vector2(8, 2)
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(title_label)

	# Create labels for all destinations + 1 for CUSTOM entry
	var total_items := DESTINATIONS.size() + 1
	for i in range(total_items):
		var lbl := Label.new()
		lbl.position = Vector2(8, 18 + i * LINE_HEIGHT)
		lbl.add_theme_font_size_override("font_size", 8)
		add_child(lbl)
		labels.append(lbl)

	# Custom mode label (shown when in custom coord entry)
	custom_label = Label.new()
	custom_label.position = Vector2(8, 100)
	custom_label.add_theme_font_size_override("font_size", 10)
	custom_label.add_theme_color_override("font_color", Color.GREEN)
	custom_label.visible = false
	add_child(custom_label)


func open() -> void:
	is_open = true
	visible = true
	cursor_index = 0
	scroll_offset = 0
	custom_mode = false
	custom_label.visible = false
	get_tree().paused = true
	_refresh_labels()


func close() -> void:
	is_open = false
	visible = false
	custom_mode = false
	custom_label.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not (event is InputEventKey and event.pressed):
		return

	get_viewport().set_input_as_handled()

	if event.keycode == KEY_ESCAPE or event.keycode == KEY_0:
		if custom_mode:
			custom_mode = false
			custom_label.visible = false
			_show_list_labels(true)
			_refresh_labels()
		else:
			close()
		return

	if custom_mode:
		_handle_custom_input(event)
		return

	var total_items := DESTINATIONS.size() + 1
	match event.keycode:
		KEY_UP, KEY_W:
			cursor_index = max(0, cursor_index - 1)
			_adjust_scroll()
			_refresh_labels()
		KEY_DOWN, KEY_S:
			cursor_index = min(total_items - 1, cursor_index + 1)
			_adjust_scroll()
			_refresh_labels()
		KEY_ENTER, KEY_X:
			if cursor_index < DESTINATIONS.size():
				_warp_to(DESTINATIONS[cursor_index])
			else:
				custom_mode = true
				custom_label.visible = true
				_show_list_labels(false)
				_update_custom_label()


func _handle_custom_input(event: InputEvent) -> void:
	match event.keycode:
		KEY_LEFT, KEY_A:
			custom_x = max(0, custom_x - 1)
		KEY_RIGHT, KEY_D:
			custom_x = min(15, custom_x + 1)
		KEY_UP, KEY_W:
			custom_y = max(0, custom_y - 1)
		KEY_DOWN, KEY_S:
			custom_y = min(7, custom_y + 1)
		KEY_ENTER, KEY_X:
			_warp_to({"screen": Vector2i(custom_x, custom_y), "tile": Vector2i(7, 5)})
			return
	_update_custom_label()


func _adjust_scroll() -> void:
	if cursor_index < scroll_offset:
		scroll_offset = cursor_index
	elif cursor_index >= scroll_offset + VISIBLE_ROWS:
		scroll_offset = cursor_index - VISIBLE_ROWS + 1


func _refresh_labels() -> void:
	var total_items := DESTINATIONS.size() + 1
	for i in range(labels.size()):
		var display_index := scroll_offset + i
		if display_index >= total_items:
			labels[i].text = ""
			continue

		var is_selected := (display_index == cursor_index)
		var prefix := "> " if is_selected else "  "
		labels[i].add_theme_color_override("font_color", Color.GREEN if is_selected else Color.WHITE)

		if display_index < DESTINATIONS.size():
			var d: Dictionary = DESTINATIONS[display_index]
			labels[i].text = "%s%s (%d,%d)" % [prefix, d["name"], d["screen"].x, d["screen"].y]
		else:
			labels[i].text = "%sCUSTOM COORDS..." % prefix

		labels[i].position.y = 18 + i * LINE_HEIGHT


func _show_list_labels(show: bool) -> void:
	for lbl in labels:
		lbl.visible = show
	title_label.text = "CUSTOM WARP  0=BACK" if not show else "WARP MENU  0=CLOSE"


func _update_custom_label() -> void:
	custom_label.text = "ARROWS TO PICK SCREEN\nENTER/X TO WARP\n\nSCREEN: %d, %d" % [custom_x, custom_y]


func _warp_to(dest: Dictionary) -> void:
	var sm = get_tree().current_scene
	var player = sm.get_node_or_null("Player") if sm else null
	if not player or not sm:
		close()
		return

	var target_screen: Vector2i = dest["screen"]
	var target_tile: Vector2i = dest["tile"]
	var screen_origin := Vector2(target_screen.x * 256, target_screen.y * 176)
	var new_pos := Vector2(
		screen_origin.x + target_tile.x * 16 + 8.0,
		screen_origin.y + target_tile.y * 16 + 8.0
	)

	player.global_position = new_pos
	if "subpixel_position" in player:
		player.subpixel_position = new_pos

	sm.current_screen = target_screen
	sm.center_camera_on_screen(target_screen)
	sm._spawn_enemies_for_screen(target_screen)

	if sm.hud:
		sm.hud.update_minimap(target_screen)

	close()
	print("DEBUG: Warped to screen ", target_screen)
