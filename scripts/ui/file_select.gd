extends CanvasLayer
## File Select screen with SELECT, REGISTER, and ELIMINATION modes.
## Allows player to create, select, or delete save files.

const FILE_SELECT_TEXTURE_PATH := "res://assets/File_Select.png"

# Frame regions from File_Select.png
const SELECT_FRAME_REGION := Rect2(1, 1, 246, 224)
const REGISTER_FRAME_REGION := Rect2(258, 1, 246, 224)

# Icon regions
const PLAYER_ICON_REGION := Rect2(1, 230, 16, 16)
const HEART_ICON_REGION := Rect2(52, 230, 8, 8)
const CURSOR_ICON_REGION := Rect2(61, 230, 8, 8)

# Frame positioning (centered in 256x232 viewport)
const FRAME_OFFSET := Vector2(5, 4)  # Small offset to center 246px in 256px

# Slot display positions (relative to frame)
# Player icon is 16x16, positioned to the right of cursor (cursor at x=39)
const SLOT_NAME_X := 72
const SLOT_HEARTS_X := 144
const SLOT_POSITIONS := [
	Vector2(48, 84),   # Slot 1 - player icon position (to right of cursor)
	Vector2(48, 108),  # Slot 2
	Vector2(48, 132),  # Slot 3
]

# Cursor positions for SELECT mode (from gray #c0c0c0 squares in sprite sheet)
# Sprite sheet coords match frame-relative coords (no offset needed)
const SELECT_CURSOR_POSITIONS := [
	Vector2(40, 85),   # File 1
	Vector2(40, 109),  # File 2
	Vector2(40, 133),  # File 3
	Vector2(40, 161),  # REGISTER YOUR NAME
	Vector2(40, 177),  # ELIMINATION MODE
]

# REGISTER mode - alphabet grid configuration
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ-.,!'&.0123456789"
const GRID_COLS := 11
const GRID_ROWS := 4
const GRID_START := Vector2(48, 128)  # Grid position in register frame (aligned with letters)
const GRID_CELL_SIZE := Vector2(16, 16)  # 16px spacing for character grid

# REGISTER cursor positions (grid + REGISTER/END options)
const REGISTER_OPTION_POS := Vector2(67, 112)   # "REGISTER" button
const END_OPTION_POS := Vector2(164, 112)       # "END" button

# Screen modes
enum Mode { SELECT, REGISTER, ELIMINATION }
var current_mode := Mode.SELECT

# Cursor state
var cursor_index := 0  # For SELECT/ELIMINATION modes (0-4)
var grid_cursor := Vector2i(0, 0)  # For REGISTER mode grid
var register_option := 0  # 0 = grid, 1 = REGISTER, 2 = END

# Name entry state
var entered_name := ""
var target_slot := 0  # Slot being registered or eliminated

# Blink state
var blink_timer := 0.0
var cursor_visible := true
const CURSOR_BLINK_RATE := 0.125  # Fast blink for NES feel

# Texture and node references
var file_texture: Texture2D
var frame_sprite: Sprite2D
var cursor_sprite: Sprite2D
var player_icons: Array[Sprite2D] = []
var heart_containers: Array[Control] = []
var name_labels: Array[Control] = []
var name_preview_container: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	file_texture = load(FILE_SELECT_TEXTURE_PATH)
	_build_file_select()
	_refresh_display()


func _build_file_select() -> void:
	## Construct the file select UI

	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(256, 232)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Main frame sprite (changes based on mode)
	frame_sprite = Sprite2D.new()
	frame_sprite.texture = file_texture
	frame_sprite.region_enabled = true
	frame_sprite.region_rect = SELECT_FRAME_REGION
	frame_sprite.centered = false
	frame_sprite.position = FRAME_OFFSET
	add_child(frame_sprite)

	# Cursor sprite
	cursor_sprite = Sprite2D.new()
	cursor_sprite.texture = file_texture
	cursor_sprite.region_enabled = true
	cursor_sprite.region_rect = CURSOR_ICON_REGION
	cursor_sprite.centered = false
	add_child(cursor_sprite)

	# Create slot display elements
	for i in range(3):
		# Player icon for each slot
		var player_icon := Sprite2D.new()
		player_icon.texture = file_texture
		player_icon.region_enabled = true
		player_icon.region_rect = PLAYER_ICON_REGION
		player_icon.centered = false
		player_icon.position = FRAME_OFFSET + SLOT_POSITIONS[i]
		player_icon.visible = false
		add_child(player_icon)
		player_icons.append(player_icon)

		# Heart container for each slot
		var hearts := Control.new()
		hearts.position = FRAME_OFFSET + Vector2(SLOT_HEARTS_X, SLOT_POSITIONS[i].y - 4)
		add_child(hearts)
		heart_containers.append(hearts)

		# Name label placeholder (will be populated with sprites)
		var name_container := Control.new()
		name_container.position = FRAME_OFFSET + Vector2(SLOT_NAME_X, SLOT_POSITIONS[i].y - 4)
		add_child(name_container)
		name_labels.append(name_container)

	# Name preview for REGISTER mode
	name_preview_container = Control.new()
	name_preview_container.position = FRAME_OFFSET + Vector2(80, 48)
	name_preview_container.visible = false
	add_child(name_preview_container)

	_update_cursor_position()


func _process(delta: float) -> void:
	# Cursor blink
	blink_timer += delta
	if blink_timer >= CURSOR_BLINK_RATE:
		blink_timer = 0.0
		cursor_visible = not cursor_visible
		cursor_sprite.visible = cursor_visible


func _unhandled_input(event: InputEvent) -> void:
	match current_mode:
		Mode.SELECT:
			_handle_select_input(event)
		Mode.REGISTER:
			_handle_register_input(event)
		Mode.ELIMINATION:
			_handle_elimination_input(event)


func _handle_select_input(event: InputEvent) -> void:
	## Handle input in SELECT mode
	if event.is_action_pressed("move_up"):
		cursor_index = (cursor_index - 1 + 5) % 5
		_update_cursor_position()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_down"):
		cursor_index = (cursor_index + 1) % 5
		_update_cursor_position()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("attack") or event.is_action_pressed("start"):
		get_viewport().set_input_as_handled()
		_select_option()


func _handle_register_input(event: InputEvent) -> void:
	## Handle input in REGISTER mode (name entry)
	if register_option == 0:
		# Grid navigation
		if event.is_action_pressed("move_up"):
			if grid_cursor.y > 0:
				grid_cursor.y -= 1
			else:
				# Move to REGISTER/END options
				register_option = 1
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("move_down"):
			if grid_cursor.y < GRID_ROWS - 1:
				grid_cursor.y += 1
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("move_left"):
			grid_cursor.x = (grid_cursor.x - 1 + GRID_COLS) % GRID_COLS
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("move_right"):
			grid_cursor.x = (grid_cursor.x + 1) % GRID_COLS
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("attack"):
			_add_character()
			get_viewport().set_input_as_handled()

	else:
		# REGISTER/END option navigation
		if event.is_action_pressed("move_down"):
			register_option = 0
			grid_cursor = Vector2i(5, 0)  # Center of first row
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("move_left"):
			register_option = 1
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("move_right"):
			register_option = 2
			_update_cursor_position()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("attack") or event.is_action_pressed("start"):
			get_viewport().set_input_as_handled()
			if register_option == 1:
				_confirm_registration()
			else:
				_cancel_registration()

	# Backspace to delete last character
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		if entered_name.length() > 0:
			entered_name = entered_name.substr(0, entered_name.length() - 1)
			_update_name_preview()
		get_viewport().set_input_as_handled()


func _handle_elimination_input(event: InputEvent) -> void:
	## Handle input in ELIMINATION mode
	if event.is_action_pressed("move_up"):
		if cursor_index > 0:
			cursor_index -= 1
			_update_cursor_position()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("move_down"):
		if cursor_index < 2:
			cursor_index += 1
			_update_cursor_position()
		else:
			# Moving past bottom slot exits elimination mode
			_switch_to_select()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("attack") or event.is_action_pressed("start"):
		_delete_save(cursor_index)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("pause"):
		_switch_to_select()
		get_viewport().set_input_as_handled()


func _select_option() -> void:
	## Process selection in SELECT mode
	if cursor_index < 3:
		# Selected a save slot
		if SaveManager.is_slot_empty(cursor_index):
			# Empty slot - go to register for this slot
			target_slot = cursor_index
			_switch_to_register()
		else:
			# Existing save - load and start game
			_start_game(cursor_index)
	elif cursor_index == 3:
		# REGISTER YOUR NAME - find first empty slot
		for i in range(3):
			if SaveManager.is_slot_empty(i):
				target_slot = i
				_switch_to_register()
				return
		# All slots full - could show message
	else:
		# ELIMINATION MODE
		_switch_to_elimination()


func _switch_to_select() -> void:
	## Switch to SELECT mode
	current_mode = Mode.SELECT
	cursor_index = 0
	frame_sprite.region_rect = SELECT_FRAME_REGION
	name_preview_container.visible = false
	_refresh_display()
	_update_cursor_position()


func _switch_to_register() -> void:
	## Switch to REGISTER mode for name entry
	current_mode = Mode.REGISTER
	entered_name = ""
	grid_cursor = Vector2i(0, 0)
	register_option = 0
	frame_sprite.region_rect = REGISTER_FRAME_REGION
	name_preview_container.visible = true
	_update_name_preview()
	_update_cursor_position()


func _switch_to_elimination() -> void:
	## Switch to ELIMINATION mode
	current_mode = Mode.ELIMINATION
	cursor_index = 0
	# Use same frame as select but behavior changes
	_refresh_display()
	_update_cursor_position()


func _add_character() -> void:
	## Add character from grid to entered name
	if entered_name.length() >= SaveManager.MAX_NAME_LENGTH:
		return

	var char_index := grid_cursor.y * GRID_COLS + grid_cursor.x
	if char_index < ALPHABET.length():
		entered_name += ALPHABET[char_index]
		_update_name_preview()


func _confirm_registration() -> void:
	## Confirm name entry and create save
	if entered_name.length() == 0:
		return

	if SaveManager.create_new_save(target_slot, entered_name):
		_start_game(target_slot)


func _cancel_registration() -> void:
	## Cancel name entry and return to select
	_switch_to_select()


func _delete_save(slot: int) -> void:
	## Delete a save file
	if SaveManager.is_slot_empty(slot):
		return

	SaveManager.delete_save(slot)
	_refresh_display()


func _start_game(slot: int) -> void:
	## Load save and start the game
	SaveManager.load_save(slot)
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")


func _update_cursor_position() -> void:
	## Update cursor sprite position based on current mode and selection
	var pos := Vector2.ZERO

	match current_mode:
		Mode.SELECT:
			pos = FRAME_OFFSET + SELECT_CURSOR_POSITIONS[cursor_index]

		Mode.REGISTER:
			if register_option == 0:
				# Grid cursor
				pos = FRAME_OFFSET + GRID_START + Vector2(
					grid_cursor.x * GRID_CELL_SIZE.x,
					grid_cursor.y * GRID_CELL_SIZE.y
				)
			elif register_option == 1:
				pos = FRAME_OFFSET + REGISTER_OPTION_POS
			else:
				pos = FRAME_OFFSET + END_OPTION_POS

		Mode.ELIMINATION:
			if cursor_index < 3:
				pos = FRAME_OFFSET + SELECT_CURSOR_POSITIONS[cursor_index]
			else:
				# Back option at bottom
				pos = FRAME_OFFSET + Vector2(16, 184)

	cursor_sprite.position = pos
	cursor_visible = true
	blink_timer = 0.0


func _refresh_display() -> void:
	## Refresh all slot displays with current save data
	for i in range(3):
		var is_empty := SaveManager.is_slot_empty(i)
		player_icons[i].visible = not is_empty

		# Clear and rebuild hearts
		for child in heart_containers[i].get_children():
			child.queue_free()

		# Clear and rebuild name
		for child in name_labels[i].get_children():
			child.queue_free()

		if not is_empty:
			var data := SaveManager.get_slot_data(i)
			_display_slot_hearts(i, data.get("hearts", 3))
			_display_slot_name(i, data.get("name", ""))


func _display_slot_hearts(slot: int, count: int) -> void:
	## Display heart icons for a save slot
	var container := heart_containers[slot]
	for h in range(count):
		var heart := Sprite2D.new()
		heart.texture = file_texture
		heart.region_enabled = true
		heart.region_rect = HEART_ICON_REGION
		heart.centered = false
		heart.position = Vector2(h * 8, 0)
		container.add_child(heart)


func _display_slot_name(slot: int, player_name: String) -> void:
	## Display player name for a save slot using FontManager
	var container := name_labels[slot]
	FontManager.create_text_sprites(player_name.to_upper(), FontManager.FontColor.WHITE, container)


func _update_name_preview() -> void:
	## Update the name preview in REGISTER mode
	for child in name_preview_container.get_children():
		child.queue_free()

	# Display entered name using FontManager
	if entered_name.length() > 0:
		FontManager.create_text_sprites(entered_name.to_upper(), FontManager.FontColor.RED, name_preview_container)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Cleanup
		pass
