extends CanvasLayer
## HUD display showing minimap, inventory counters, items, and hearts.
## Styled after the original Legend of Zelda NES HUD.

const HUD_TEXTURE_PATH := "res://assets/HUDs.png"

# HUD frame region (256x56)
const HUD_FRAME_REGION := Rect2(258, 11, 256, 56)

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

# Item/weapon sprite regions (8x16 each unless noted)
const ITEM_REGIONS := {
	"wooden_sword": Rect2(555, 137, 8, 16),
	"white_sword": Rect2(564, 137, 8, 16),
	"magic_sword": Rect2(573, 137, 8, 16),
	"boomerang": Rect2(584, 137, 8, 16),
	"magic_boomerang": Rect2(593, 137, 8, 16),
	"bomb": Rect2(604, 137, 8, 16),
	"bombs": Rect2(604, 137, 8, 16),  # Alias for bomb
	"arrow": Rect2(615, 137, 8, 16),
	"silver_arrow": Rect2(624, 137, 8, 16),
	"bow": Rect2(633, 137, 8, 16),
	"red_candle": Rect2(644, 137, 8, 16),
	"blue_candle": Rect2(653, 137, 8, 16),
	"candle": Rect2(653, 137, 8, 16),  # Default to blue candle
	"magic_book": Rect2(538, 156, 8, 16),
	"flute": Rect2(664, 137, 8, 16),
	"recorder": Rect2(664, 137, 8, 16),  # Alias for flute
	"food_bait": Rect2(675, 137, 8, 16),
	"food": Rect2(675, 137, 8, 16),  # Alias for food_bait
	"magic_wand": Rect2(715, 137, 8, 16),
	"wand": Rect2(715, 137, 8, 16),  # Alias for magic_wand
	"letter": Rect2(686, 137, 8, 16),
}

# Item slot positions (B = usable item, A = sword)
const B_SLOT_POS := Vector2(129, 25)
const A_SLOT_POS := Vector2(153, 25)

# Heart display configuration (original Zelda: 2 rows of 8)
const MAX_HEART_CONTAINERS := 16
const HEARTS_PER_ROW := 8
const HEART_SPACING := 8
const HEART_START_X := 176  # Right side of HUD (based on original Zelda layout)
const HEART_START_Y := 32   # Below "-LIFE-" text area

# Counter positions (relative to HUD frame, matching sprite layout)
const RUPEE_COUNT_POS := Vector2(97, 17)
const KEY_COUNT_POS := Vector2(97, 33)
const BOMB_COUNT_POS := Vector2(97, 41)

# Minimap configuration (16x8 overworld grid)
const MINIMAP_POS := Vector2(16, 16)
const MINIMAP_CELL_SIZE := Vector2(4, 4)  # Each screen shown as 4x4 pixels
const OVERWORLD_SCREENS_X := 16
const OVERWORLD_SCREENS_Y := 8
const MINIMAP_COLOR := Color(0.0, 0.5, 0.0)  # Dark green for map outline
const MINIMAP_CURRENT_COLOR := Color(0.0, 1.0, 0.0)  # Bright green for current pos

# Texture reference
var hud_texture: Texture2D

# Node references (set up in _ready)
var hud_frame: Sprite2D
var hearts_container: Control
var minimap_control: Control
var rupee_display: Control
var key_display: Control
var bomb_display: Control
var b_slot_sprite: Sprite2D
var a_slot_sprite: Sprite2D

# Heart sprite array
var heart_sprites: Array[Sprite2D] = []

# Minimap state
var current_screen := Vector2i(7, 7)
var blink_timer := 0.0
var blink_visible := true

# Player reference for health tracking
var player_ref: WeakRef


func _ready() -> void:
	layer = 1  # Render above game world
	hud_texture = load(HUD_TEXTURE_PATH)

	_create_hud_structure()
	_setup_hearts()

	# Connect to GameManager signals
	GameManager.rupees_changed.connect(_on_rupees_changed)
	GameManager.keys_changed.connect(_on_keys_changed)
	GameManager.bombs_changed.connect(_on_bombs_changed)
	GameManager.sword_changed.connect(_on_sword_changed)
	GameManager.equipped_item_changed.connect(_on_equipped_item_changed)

	# Initialize counter displays with current values
	_on_rupees_changed(GameManager.rupees)
	_on_keys_changed(GameManager.keys)
	_on_bombs_changed(GameManager.bombs)

	# Initialize sword display based on current state
	_on_sword_changed(GameManager.current_sword)

	# Initialize B-slot display with current equipped item
	_on_equipped_item_changed(GameManager._item_to_string(GameManager.equipped_item))


func _process(delta: float) -> void:
	# Blink minimap current position indicator
	blink_timer += delta
	if blink_timer >= 0.25:
		blink_timer = 0.0
		blink_visible = not blink_visible
		minimap_control.queue_redraw()


func _create_hud_structure() -> void:
	## Build the HUD node hierarchy programmatically

	# Black background for HUD area
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(256, 56)
	bg.position = Vector2.ZERO
	add_child(bg)

	# HUD frame sprite
	hud_frame = Sprite2D.new()
	hud_frame.texture = hud_texture
	hud_frame.region_enabled = true
	hud_frame.region_rect = HUD_FRAME_REGION
	hud_frame.centered = false
	hud_frame.position = Vector2.ZERO
	add_child(hud_frame)

	# Hearts container
	hearts_container = Control.new()
	hearts_container.name = "HeartsContainer"
	add_child(hearts_container)

	# Minimap control (custom drawing)
	minimap_control = Control.new()
	minimap_control.name = "MinimapControl"
	minimap_control.position = MINIMAP_POS
	minimap_control.custom_minimum_size = Vector2(
		OVERWORLD_SCREENS_X * MINIMAP_CELL_SIZE.x,
		OVERWORLD_SCREENS_Y * MINIMAP_CELL_SIZE.y
	)
	minimap_control.draw.connect(_draw_minimap)
	add_child(minimap_control)

	# Counter displays
	rupee_display = Control.new()
	rupee_display.name = "RupeeDisplay"
	rupee_display.position = RUPEE_COUNT_POS
	add_child(rupee_display)

	key_display = Control.new()
	key_display.name = "KeyDisplay"
	key_display.position = KEY_COUNT_POS
	add_child(key_display)

	bomb_display = Control.new()
	bomb_display.name = "BombDisplay"
	bomb_display.position = BOMB_COUNT_POS
	add_child(bomb_display)

	# B slot (usable item)
	b_slot_sprite = Sprite2D.new()
	b_slot_sprite.name = "BSlot"
	b_slot_sprite.texture = hud_texture
	b_slot_sprite.region_enabled = true
	b_slot_sprite.centered = false
	b_slot_sprite.position = B_SLOT_POS
	b_slot_sprite.visible = false  # Hidden until item equipped
	add_child(b_slot_sprite)

	# A slot (sword)
	a_slot_sprite = Sprite2D.new()
	a_slot_sprite.name = "ASlot"
	a_slot_sprite.texture = hud_texture
	a_slot_sprite.region_enabled = true
	a_slot_sprite.centered = false
	a_slot_sprite.position = A_SLOT_POS
	a_slot_sprite.visible = false  # Hidden until sword acquired
	add_child(a_slot_sprite)


func _setup_hearts() -> void:
	## Create heart sprites for health display
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
			HEART_START_Y + row * HEART_SPACING
		)
		heart.visible = false  # Hide until we know max health

		hearts_container.add_child(heart)
		heart_sprites.append(heart)


func connect_to_player(player: Node) -> void:
	## Connect to player health signals
	player_ref = weakref(player)

	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		# Trigger initial update
		if "health" in player and "max_health" in player:
			_on_health_changed(player.health, player.max_health)


func update_minimap(screen_pos: Vector2i) -> void:
	## Update minimap to show current screen position
	current_screen = screen_pos
	minimap_control.queue_redraw()


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

	# Draw current position (blinking)
	if blink_visible:
		var current_rect := Rect2(
			current_screen.x * MINIMAP_CELL_SIZE.x,
			current_screen.y * MINIMAP_CELL_SIZE.y,
			MINIMAP_CELL_SIZE.x,
			MINIMAP_CELL_SIZE.y
		)
		minimap_control.draw_rect(current_rect, MINIMAP_CURRENT_COLOR, true)


func _on_health_changed(current: int, maximum: int) -> void:
	## Update heart display based on health
	# Health is in whole hearts (current=3 means 3 full hearts)
	for i in range(MAX_HEART_CONTAINERS):
		var heart := heart_sprites[i]

		if i < maximum:
			# This heart container exists
			heart.visible = true
			if i < current:
				heart.region_rect = HEART_FULL_REGION
			else:
				heart.region_rect = HEART_EMPTY_REGION
		else:
			# No heart container at this position
			heart.visible = false


func _on_rupees_changed(amount: int) -> void:
	## Update rupee counter display
	_update_number_display(rupee_display, amount, 2)


func _on_keys_changed(amount: int) -> void:
	## Update key counter display
	_update_number_display(key_display, amount, 1)


func _on_bombs_changed(amount: int) -> void:
	## Update bomb counter display
	_update_number_display(bomb_display, amount, 1)


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
		sprite.position = Vector2(8 + i * 8, 0)  # Start after "X"
		container.add_child(sprite)


func set_b_slot_item(item_name: String) -> void:
	## Set the item displayed in the B slot
	if item_name == "" or item_name == "none":
		b_slot_sprite.visible = false
	elif item_name in ITEM_REGIONS:
		b_slot_sprite.region_rect = ITEM_REGIONS[item_name]
		b_slot_sprite.visible = true


func set_a_slot_item(item_name: String) -> void:
	## Set the item displayed in the A slot (sword)
	if item_name == "" or item_name == "none":
		a_slot_sprite.visible = false
	elif item_name in ITEM_REGIONS:
		a_slot_sprite.region_rect = ITEM_REGIONS[item_name]
		a_slot_sprite.visible = true


func _on_sword_changed(sword_type: GameManager.Sword) -> void:
	## Update A slot display when sword changes
	match sword_type:
		GameManager.Sword.WOODEN:
			set_a_slot_item("wooden_sword")
		GameManager.Sword.WHITE:
			set_a_slot_item("white_sword")
		GameManager.Sword.MAGICAL:
			set_a_slot_item("magic_sword")
		_:
			set_a_slot_item("none")


func _on_equipped_item_changed(item_name: String) -> void:
	## Update B slot display when equipped item changes
	set_b_slot_item(item_name)
