extends CanvasLayer
## Pause menu displaying inventory, triforce/dungeon map, and HUD.
## Shows three sections vertically: Inventory (top), Triforce/Dungeon (middle), HUD (bottom).

const HUD_TEXTURE_PATH := "res://assets/HUDs.png"

# Frame regions from HUDs.png
const INVENTORY_FRAME_REGION := Rect2(1, 11, 256, 88)
const TRIFORCE_FRAME_REGION := Rect2(1, 112, 256, 88)
const DUNGEON_FRAME_REGION := Rect2(258, 112, 256, 88)
const HUD_FRAME_REGION := Rect2(258, 11, 256, 56)

# Cursor region (16x16)
const CURSOR_REGION := Rect2(519, 137, 16, 16)

# Heart sprite regions (8x8 each)
const HEART_FULL_REGION := Rect2(645, 117, 8, 8)
const HEART_HALF_REGION := Rect2(636, 117, 8, 8)
const HEART_EMPTY_REGION := Rect2(627, 117, 8, 8)

# Number sprite regions (8x8 each) - 0-9
const NUMBER_REGIONS := [
	Rect2(528, 117, 8, 8),  # 0
	Rect2(537, 117, 8, 8),  # 1
	Rect2(546, 117, 8, 8),  # 2
	Rect2(555, 117, 8, 8),  # 3
	Rect2(564, 117, 8, 8),  # 4
	Rect2(573, 117, 8, 8),  # 5
	Rect2(582, 117, 8, 8),  # 6
	Rect2(591, 117, 8, 8),  # 7
	Rect2(600, 117, 8, 8),  # 8
	Rect2(609, 117, 8, 8),  # 9
]
const X_REGION := Rect2(519, 117, 8, 8)  # "X" prefix for counters

# Sword display configuration (left side of inventory frame)
const SWORD_SLOT_POS := Vector2(68, 49)  # Position in inventory frame
# Sword sprites from HUDs.png (same as hud.gd)
const WOODEN_SWORD_REGION := Rect2(555, 137, 8, 16)
const WHITE_SWORD_REGION := Rect2(564, 137, 8, 16)
const MAGICAL_SWORD_REGION := Rect2(573, 137, 8, 16)

# HUD section offset (bottom panel starts at y=176)
const HUD_SECTION_Y := 176

# Heart display configuration (matching hud.gd)
const MAX_HEART_CONTAINERS := 16
const HEARTS_PER_ROW := 8
const HEART_SPACING := 8
const HEART_START_X := 176
const HEART_START_Y := 32  # Relative to HUD frame

# Counter positions relative to HUD frame
const RUPEE_COUNT_POS := Vector2(97, 17)
const KEY_COUNT_POS := Vector2(97, 33)
const BOMB_COUNT_POS := Vector2(97, 41)

# Minimap configuration
const MINIMAP_POS := Vector2(16, 16)
const MINIMAP_CELL_SIZE := Vector2(4, 4)
const OVERWORLD_SCREENS_X := 16
const OVERWORLD_SCREENS_Y := 8
const MINIMAP_COLOR := Color(0.0, 0.5, 0.0)
const MINIMAP_CURRENT_COLOR := Color(0.0, 1.0, 0.0)

# Grid layout for selectable B-button items
# Maps grid position (col, row) to item enum name
const INVENTORY_GRID := [
	["boomerang", "bombs", "arrow", "bow", "candle"],  # Row 0 (y=49)
	["recorder", "food", "potion", "wand", ""],        # Row 1 (y=65)
]

# Grid cell positions relative to inventory frame (col, row) -> pixel position
const GRID_POSITIONS := {
	Vector2i(0, 0): Vector2(133, 49),   # Boomerang
	Vector2i(1, 0): Vector2(157, 49),   # Bombs
	Vector2i(2, 0): Vector2(177, 49),   # Arrows
	Vector2i(3, 0): Vector2(185, 49),   # Bow
	Vector2i(4, 0): Vector2(205, 49),   # Candle
	Vector2i(0, 1): Vector2(133, 65),   # Flute/Recorder
	Vector2i(1, 1): Vector2(157, 65),   # Food
	Vector2i(2, 1): Vector2(181, 65),   # Potion
	Vector2i(3, 1): Vector2(205, 65),   # Magic Wand
}

# B-slot display position in inventory frame
const B_SLOT_DISPLAY_POS := Vector2(69, 49)

# All item placeholder positions in inventory frame (to mask when not owned)
# Format: item_name -> {position, size}
const ITEM_PLACEHOLDERS := {
	"raft": {"pos": Vector2(129, 25), "size": Vector2(16, 16)},
	"magic_book": {"pos": Vector2(153, 25), "size": Vector2(8, 16)},
	"magic_ring": {"pos": Vector2(165, 25), "size": Vector2(8, 16)},
	"ladder": {"pos": Vector2(177, 25), "size": Vector2(16, 16)},
	"master_key": {"pos": Vector2(197, 25), "size": Vector2(8, 16)},
	"bracelet": {"pos": Vector2(209, 25), "size": Vector2(8, 16)},
	"boomerang": {"pos": Vector2(133, 49), "size": Vector2(8, 16)},
	"bombs": {"pos": Vector2(157, 49), "size": Vector2(8, 16)},
	"arrow": {"pos": Vector2(177, 49), "size": Vector2(8, 16)},
	"bow": {"pos": Vector2(185, 49), "size": Vector2(8, 16)},
	"candle": {"pos": Vector2(205, 49), "size": Vector2(8, 16)},
	"recorder": {"pos": Vector2(133, 65), "size": Vector2(8, 16)},
	"food": {"pos": Vector2(157, 65), "size": Vector2(8, 16)},
	"potion": {"pos": Vector2(181, 65), "size": Vector2(8, 16)},
	"wand": {"pos": Vector2(205, 65), "size": Vector2(8, 16)},
}

# State
var cursor_grid_pos := Vector2i(0, 0)
var blink_timer := 0.0
var cursor_visible := true
var selectable_positions: Array[Vector2i] = []

# Texture reference
var hud_texture: Texture2D

# Node references
var inventory_frame: Sprite2D
var middle_frame: Sprite2D
var hud_frame: Sprite2D
var cursor_sprite: Sprite2D
var b_slot_sprite: Sprite2D
var item_sprites: Dictionary = {}  # Grid pos -> Sprite2D

# HUD section node references
var heart_sprites: Array[Sprite2D] = []
var rupee_display: Control
var key_display: Control
var bomb_display: Control
var minimap_control: Control
var current_screen := Vector2i(7, 7)  # Default screen position

# Item sprites for inventory display (drawn when owned)
var inventory_item_sprites: Dictionary = {}  # item_name -> Sprite2D

# Sword display
var sword_sprite: Sprite2D


func _ready() -> void:
	layer = 10  # Render above game and HUD
	process_mode = Node.PROCESS_MODE_ALWAYS  # Process while game is paused
	visible = false

	hud_texture = load(HUD_TEXTURE_PATH)
	_build_menu_structure()

	# Connect to GameManager signals
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)


func _build_menu_structure() -> void:
	## Build menu UI programmatically (matching HUD.gd pattern)

	# Black background for full screen
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(256, 232)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Inventory frame (top section, 256x88)
	inventory_frame = _create_frame_sprite(INVENTORY_FRAME_REGION, Vector2(0, 0))

	# Middle frame - Triforce (default) or Dungeon (256x88)
	middle_frame = _create_frame_sprite(TRIFORCE_FRAME_REGION, Vector2(0, 88))

	# HUD frame (bottom section, 256x56) - positioned to fill remaining space
	hud_frame = _create_frame_sprite(HUD_FRAME_REGION, Vector2(0, 176))

	# Cursor sprite (16x16, blinking)
	cursor_sprite = Sprite2D.new()
	cursor_sprite.texture = hud_texture
	cursor_sprite.region_enabled = true
	cursor_sprite.region_rect = CURSOR_REGION
	cursor_sprite.centered = false
	add_child(cursor_sprite)

	# B-slot display sprite (shows currently equipped item)
	b_slot_sprite = Sprite2D.new()
	b_slot_sprite.texture = hud_texture
	b_slot_sprite.region_enabled = true
	b_slot_sprite.centered = false
	b_slot_sprite.position = B_SLOT_DISPLAY_POS
	b_slot_sprite.visible = false
	add_child(b_slot_sprite)

	# Sword display sprite (left side of inventory)
	sword_sprite = Sprite2D.new()
	sword_sprite.texture = hud_texture
	sword_sprite.region_enabled = true
	sword_sprite.centered = false
	sword_sprite.position = SWORD_SLOT_POS
	sword_sprite.visible = false
	add_child(sword_sprite)

	# Create item sprites for all grid positions
	_create_item_sprites()

	# Create item sprites for inventory placeholders
	_create_inventory_item_sprites()

	# Create HUD section elements (bottom panel)
	_create_hud_elements()


func _create_frame_sprite(region: Rect2, pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = hud_texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.position = pos
	add_child(sprite)
	return sprite


func _create_item_sprites() -> void:
	## Create sprite nodes for each inventory slot
	for grid_pos in GRID_POSITIONS:
		var sprite := Sprite2D.new()
		sprite.texture = hud_texture
		sprite.region_enabled = true
		sprite.centered = false
		sprite.position = GRID_POSITIONS[grid_pos]
		sprite.visible = false
		add_child(sprite)
		item_sprites[grid_pos] = sprite


func _create_inventory_item_sprites() -> void:
	## Create sprites for each inventory item placeholder (shown when owned)
	for item_name in ITEM_PLACEHOLDERS:
		var placeholder: Dictionary = ITEM_PLACEHOLDERS[item_name]
		var sprite := Sprite2D.new()
		sprite.texture = hud_texture
		sprite.region_enabled = true
		sprite.centered = false
		sprite.position = placeholder["pos"]
		sprite.visible = false  # Hidden until owned

		# Set the sprite region for this item
		var region := _get_item_region(item_name)
		if region.size != Vector2.ZERO:
			sprite.region_rect = region

		add_child(sprite)
		inventory_item_sprites[item_name] = sprite


func _create_hud_elements() -> void:
	## Create hearts, counters, and minimap for bottom HUD panel

	# Hearts container
	for i in range(MAX_HEART_CONTAINERS):
		var heart := Sprite2D.new()
		heart.texture = hud_texture
		heart.region_enabled = true
		heart.region_rect = HEART_EMPTY_REGION
		heart.centered = false

		var row := i / HEARTS_PER_ROW
		var col := i % HEARTS_PER_ROW
		heart.position = Vector2(
			HEART_START_X + col * HEART_SPACING,
			HUD_SECTION_Y + HEART_START_Y + row * HEART_SPACING
		)
		heart.visible = false
		add_child(heart)
		heart_sprites.append(heart)

	# Rupee counter
	rupee_display = Control.new()
	rupee_display.name = "RupeeDisplay"
	rupee_display.position = RUPEE_COUNT_POS + Vector2(0, HUD_SECTION_Y)
	add_child(rupee_display)

	# Key counter
	key_display = Control.new()
	key_display.name = "KeyDisplay"
	key_display.position = KEY_COUNT_POS + Vector2(0, HUD_SECTION_Y)
	add_child(key_display)

	# Bomb counter
	bomb_display = Control.new()
	bomb_display.name = "BombDisplay"
	bomb_display.position = BOMB_COUNT_POS + Vector2(0, HUD_SECTION_Y)
	add_child(bomb_display)

	# Minimap (custom drawing)
	minimap_control = Control.new()
	minimap_control.name = "MinimapControl"
	minimap_control.position = MINIMAP_POS + Vector2(0, HUD_SECTION_Y)
	minimap_control.custom_minimum_size = Vector2(
		OVERWORLD_SCREENS_X * MINIMAP_CELL_SIZE.x,
		OVERWORLD_SCREENS_Y * MINIMAP_CELL_SIZE.y
	)
	minimap_control.draw.connect(_draw_minimap)
	add_child(minimap_control)


func _process(delta: float) -> void:
	if not visible:
		return

	# Cursor blink timer (~4Hz blink rate for NES feel)
	blink_timer += delta
	if blink_timer >= 0.125:
		blink_timer = 0.0
		cursor_visible = not cursor_visible
		cursor_sprite.visible = cursor_visible and not selectable_positions.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Close menu with pause key
	if event.is_action_pressed("pause"):
		GameManager.resume_game()
		get_viewport().set_input_as_handled()
		return

	# Grid navigation
	if event.is_action_pressed("move_up"):
		_move_cursor(Vector2i(0, -1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_cursor(Vector2i(0, 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_move_cursor(Vector2i(-1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_move_cursor(Vector2i(1, 0))
		get_viewport().set_input_as_handled()

	# Item selection with attack button (Z)
	if event.is_action_pressed("attack"):
		_select_current_item()
		get_viewport().set_input_as_handled()


func _move_cursor(direction: Vector2i) -> void:
	## Move cursor to next valid selectable position in given direction
	if selectable_positions.is_empty():
		return

	var current_idx := selectable_positions.find(cursor_grid_pos)
	if current_idx == -1:
		# Cursor not on valid position, snap to first
		cursor_grid_pos = selectable_positions[0]
		_update_cursor_position()
		return

	# Find next item in the given direction
	var best_pos := cursor_grid_pos
	var best_score := INF

	for pos in selectable_positions:
		if pos == cursor_grid_pos:
			continue

		var diff := pos - cursor_grid_pos
		var valid := false
		var score := INF

		# Check if position is in the direction we want
		if direction.x > 0 and diff.x > 0:
			valid = true
			score = diff.x + abs(diff.y) * 10  # Prefer same row
		elif direction.x < 0 and diff.x < 0:
			valid = true
			score = -diff.x + abs(diff.y) * 10
		elif direction.y > 0 and diff.y > 0:
			valid = true
			score = diff.y + abs(diff.x) * 10  # Prefer same column
		elif direction.y < 0 and diff.y < 0:
			valid = true
			score = -diff.y + abs(diff.x) * 10

		if valid and score < best_score:
			best_score = score
			best_pos = pos

	cursor_grid_pos = best_pos
	_update_cursor_position()


func _update_cursor_position() -> void:
	## Update cursor sprite position based on grid position
	if cursor_grid_pos in GRID_POSITIONS:
		# Center cursor on item (cursor is 16x16, items are 8x16)
		var item_pos: Vector2 = GRID_POSITIONS[cursor_grid_pos]
		cursor_sprite.position = item_pos - Vector2(4, 0)


func _select_current_item() -> void:
	## Assign currently selected item to B-slot
	if selectable_positions.is_empty():
		return

	var col := cursor_grid_pos.x
	var row := cursor_grid_pos.y

	if row < INVENTORY_GRID.size() and col < INVENTORY_GRID[row].size():
		var item_name: String = INVENTORY_GRID[row][col]
		if item_name != "" and _player_owns_item(item_name):
			var item := _string_to_item(item_name)
			GameManager.equipped_item = item
			_update_b_slot_display()


func _on_game_paused() -> void:
	## Show pause menu and refresh inventory display
	_refresh_inventory()
	_update_middle_frame()
	_update_b_slot_display()
	_update_sword_display()
	_update_hud_display()
	visible = true

	# Reset cursor to first owned item or current equipped item
	if not selectable_positions.is_empty():
		# Try to position cursor on currently equipped item
		var equipped_name := GameManager._item_to_string(GameManager.equipped_item)
		var found := false
		for grid_pos in selectable_positions:
			var row := grid_pos.y
			var col := grid_pos.x
			if row < INVENTORY_GRID.size() and col < INVENTORY_GRID[row].size():
				if INVENTORY_GRID[row][col] == equipped_name:
					cursor_grid_pos = grid_pos
					found = true
					break

		if not found:
			cursor_grid_pos = selectable_positions[0]

		_update_cursor_position()

	cursor_visible = true
	blink_timer = 0.0
	cursor_sprite.visible = not selectable_positions.is_empty()


func _on_game_resumed() -> void:
	## Hide pause menu
	visible = false


func _refresh_inventory() -> void:
	## Update item sprites based on owned_items (show sprite when owned)
	selectable_positions.clear()

	# Update all inventory item sprites - visible when owned
	for item_name in inventory_item_sprites:
		var sprite: Sprite2D = inventory_item_sprites[item_name]
		var owns_item := _player_owns_item(item_name)
		sprite.visible = owns_item  # Show sprite when player owns item

		# Track selectable positions for B-button items
		if owns_item and item_name in _get_selectable_items():
			var grid_pos := _get_grid_pos_for_item(item_name)
			if grid_pos != Vector2i(-1, -1):
				selectable_positions.append(grid_pos)


func _get_selectable_items() -> Array:
	## Return list of items that can be assigned to B-button
	return ["boomerang", "bombs", "arrow", "bow", "candle", "recorder", "food", "potion", "wand"]


func _get_grid_pos_for_item(item_name: String) -> Vector2i:
	## Get grid position for a given item name
	for row in range(INVENTORY_GRID.size()):
		for col in range(INVENTORY_GRID[row].size()):
			if INVENTORY_GRID[row][col] == item_name:
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _get_item_region(item_name: String) -> Rect2:
	## Get sprite region for an item (references hud.gd constants)
	# Hardcoded regions matching hud.gd ITEM_REGIONS
	var regions := {
		"boomerang": Rect2(584, 137, 8, 16),
		"magic_boomerang": Rect2(593, 137, 8, 16),
		"bombs": Rect2(604, 137, 8, 16),
		"bomb": Rect2(604, 137, 8, 16),
		"arrow": Rect2(615, 137, 8, 16),
		"silver_arrow": Rect2(624, 137, 8, 16),
		"bow": Rect2(633, 137, 8, 16),
		"candle": Rect2(653, 137, 8, 16),
		"red_candle": Rect2(644, 137, 8, 16),
		"blue_candle": Rect2(653, 137, 8, 16),
		"recorder": Rect2(664, 137, 8, 16),
		"flute": Rect2(664, 137, 8, 16),
		"food": Rect2(675, 137, 8, 16),
		"food_bait": Rect2(675, 137, 8, 16),
		"letter": Rect2(686, 137, 8, 16),
		"potion": Rect2(695, 137, 8, 16),
		"blue_potion": Rect2(695, 137, 8, 16),
		"red_potion": Rect2(704, 137, 8, 16),
		"wand": Rect2(715, 137, 8, 16),
		"magic_wand": Rect2(715, 137, 8, 16),
	}
	return regions.get(item_name, Rect2())


func _player_owns_item(item_name: String) -> bool:
	## Check if player owns the given item
	var item := _string_to_item(item_name)
	return item != GameManager.Item.NONE and item in GameManager.owned_items


func _string_to_item(item_name: String) -> GameManager.Item:
	## Convert string to Item enum
	match item_name:
		"boomerang", "magic_boomerang": return GameManager.Item.BOOMERANG
		"bombs", "bomb": return GameManager.Item.BOMBS
		"bow": return GameManager.Item.BOW
		"candle", "red_candle", "blue_candle": return GameManager.Item.CANDLE
		"recorder", "flute": return GameManager.Item.RECORDER
		"food", "food_bait": return GameManager.Item.FOOD
		"potion", "red_potion", "blue_potion": return GameManager.Item.LETTER  # Using LETTER enum for potion
		"wand", "magic_wand": return GameManager.Item.WAND
		_: return GameManager.Item.NONE


func _update_middle_frame() -> void:
	## Switch between Triforce and Dungeon frames
	if GameManager.is_in_dungeon:
		middle_frame.region_rect = DUNGEON_FRAME_REGION
	else:
		middle_frame.region_rect = TRIFORCE_FRAME_REGION


func _update_b_slot_display() -> void:
	## Update B-slot display to show currently equipped item
	var item_name := GameManager._item_to_string(GameManager.equipped_item)
	var region := _get_item_region(item_name)
	if region.size != Vector2.ZERO:
		b_slot_sprite.region_rect = region
		b_slot_sprite.visible = true
	else:
		b_slot_sprite.visible = false


func _update_sword_display() -> void:
	## Update sword display in inventory based on equipped sword
	match GameManager.current_sword:
		GameManager.Sword.WOODEN:
			sword_sprite.region_rect = WOODEN_SWORD_REGION
			sword_sprite.visible = true
		GameManager.Sword.WHITE:
			sword_sprite.region_rect = WHITE_SWORD_REGION
			sword_sprite.visible = true
		GameManager.Sword.MAGICAL:
			sword_sprite.region_rect = MAGICAL_SWORD_REGION
			sword_sprite.visible = true
		_:
			sword_sprite.visible = false


func _update_hud_display() -> void:
	## Update all HUD elements (hearts, counters, minimap)
	_update_hearts()
	_update_counters()
	_update_minimap_position()
	minimap_control.queue_redraw()


func _update_hearts() -> void:
	## Update heart display based on player health
	var player := _get_player()
	if not player:
		return

	var current_health: int = player.health if "health" in player else 3
	var max_health: int = player.max_health if "max_health" in player else 3

	for i in range(MAX_HEART_CONTAINERS):
		var heart := heart_sprites[i]
		if i < max_health:
			heart.visible = true
			if i < current_health:
				heart.region_rect = HEART_FULL_REGION
			else:
				heart.region_rect = HEART_EMPTY_REGION
		else:
			heart.visible = false


func _update_counters() -> void:
	## Update rupee, key, and bomb counters
	_update_number_display(rupee_display, GameManager.rupees, 2)
	_update_number_display(key_display, GameManager.keys, 1)
	_update_number_display(bomb_display, GameManager.bombs, 1)


func _update_number_display(container: Control, value: int, digits: int) -> void:
	## Update a number display with "X" prefix and sprite-based digits
	# Clear existing sprites
	for child in container.get_children():
		child.queue_free()

	# Add "X" prefix sprite
	var x_sprite := Sprite2D.new()
	x_sprite.texture = hud_texture
	x_sprite.region_enabled = true
	x_sprite.region_rect = X_REGION
	x_sprite.centered = false
	x_sprite.position = Vector2(0, 0)
	container.add_child(x_sprite)

	# Format value with leading zeros
	var value_str := str(value)
	while value_str.length() < digits:
		value_str = "0" + value_str

	# Create digit sprites (offset by 8 for the "X")
	for i in range(value_str.length()):
		var digit := int(value_str[i])
		var sprite := Sprite2D.new()
		sprite.texture = hud_texture
		sprite.region_enabled = true
		sprite.region_rect = NUMBER_REGIONS[digit]
		sprite.centered = false
		sprite.position = Vector2(8 + i * 8, 0)
		container.add_child(sprite)


func _update_minimap_position() -> void:
	## Get current screen position from screen_manager
	var screen_manager := _get_screen_manager()
	if screen_manager and "current_screen" in screen_manager:
		current_screen = screen_manager.current_screen


func _draw_minimap() -> void:
	## Custom draw function for minimap
	# Draw map outline/grid
	for y in range(OVERWORLD_SCREENS_Y):
		for x in range(OVERWORLD_SCREENS_X):
			var rect := Rect2(
				x * MINIMAP_CELL_SIZE.x,
				y * MINIMAP_CELL_SIZE.y,
				MINIMAP_CELL_SIZE.x - 1,
				MINIMAP_CELL_SIZE.y - 1
			)
			minimap_control.draw_rect(rect, MINIMAP_COLOR, false)

	# Draw current position (solid, not blinking in pause menu)
	var current_rect := Rect2(
		current_screen.x * MINIMAP_CELL_SIZE.x,
		current_screen.y * MINIMAP_CELL_SIZE.y,
		MINIMAP_CELL_SIZE.x,
		MINIMAP_CELL_SIZE.y
	)
	minimap_control.draw_rect(current_rect, MINIMAP_CURRENT_COLOR, true)


func _get_player() -> Node:
	## Get player node from scene tree
	return get_tree().get_first_node_in_group("player") if get_tree() else null


func _get_screen_manager() -> Node:
	## Get screen manager (Overworld root) from scene tree
	var root := get_tree().current_scene if get_tree() else null
	return root if root and root.has_method("_process") else null
