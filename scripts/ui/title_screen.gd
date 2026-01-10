extends CanvasLayer
## Title screen with animated waterfall and blinking "PUSH START BUTTON" text.
## Transitions to File Select when player presses Start/Attack.

const TITLE_TEXTURE_PATH := "res://assets/Title.png"

# Title image region (256x186, positioned to fill screen with space for text)
const TITLE_REGION := Rect2(1, 11, 256, 186)

# Waterfall animation frames (32x16 each)
const WATERFALL_FRAMES := [
	Rect2(776, 28, 32, 16),
	Rect2(809, 28, 32, 16),
	Rect2(842, 28, 32, 16)
]

# Waterfall display position and configuration
const WATERFALL_POS := Vector2(80, 176)  # Where waterfall appears on title image
const WATERFALL_ROWS := 3  # 3 sprite rows to fill 48px height
const WATERFALL_FPS := 8.0  # Animation speed

# Text blink rate
const TEXT_BLINK_RATE := 0.5  # seconds

# State
var title_texture: Texture2D
var waterfall_sprites: Array[Sprite2D] = []
var waterfall_frame := 0
var waterfall_timer := 0.0
var blink_timer := 0.0
var text_visible := true
var start_text_sprite: Sprite2D


func _ready() -> void:
	layer = 100  # Above all game content
	process_mode = Node.PROCESS_MODE_ALWAYS

	title_texture = load(TITLE_TEXTURE_PATH)
	_build_title_screen()


func _build_title_screen() -> void:
	## Construct the title screen UI programmatically

	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(256, 232)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Title image (contains logo, mountains, waterfall background)
	var title_sprite := Sprite2D.new()
	title_sprite.texture = title_texture
	title_sprite.region_enabled = true
	title_sprite.region_rect = TITLE_REGION
	title_sprite.centered = false
	title_sprite.position = Vector2(0, 24)  # Offset to center vertically
	add_child(title_sprite)

	# Waterfall animation sprites (3 rows of 16px each = 48px total)
	var waterfall_container := Node2D.new()
	waterfall_container.name = "WaterfallContainer"
	waterfall_container.position = WATERFALL_POS + Vector2(0, 24)  # Same offset as title
	add_child(waterfall_container)

	for row in range(WATERFALL_ROWS):
		var sprite := Sprite2D.new()
		sprite.texture = title_texture
		sprite.region_enabled = true
		sprite.region_rect = WATERFALL_FRAMES[(row) % 3]  # Stagger initial frames
		sprite.centered = false
		sprite.position = Vector2(0, row * 16)
		waterfall_container.add_child(sprite)
		waterfall_sprites.append(sprite)

	# "PUSH START BUTTON" text - extract from title sheet
	# The text is part of the title image, so we create a separate sprite for blinking
	# Located at approximately y=168 in the title region
	start_text_sprite = Sprite2D.new()
	start_text_sprite.texture = title_texture
	start_text_sprite.region_enabled = true
	# "PUSH START BUTTON" text region (approximately 120x8 at center-bottom of title)
	start_text_sprite.region_rect = Rect2(68, 179, 120, 8)
	start_text_sprite.centered = false
	start_text_sprite.position = Vector2(68, 24 + 168)  # Below the main title art
	add_child(start_text_sprite)


func _process(delta: float) -> void:
	# Animate waterfall
	waterfall_timer += delta
	if waterfall_timer >= 1.0 / WATERFALL_FPS:
		waterfall_timer = 0.0
		waterfall_frame = (waterfall_frame + 1) % 3
		_update_waterfall()

	# Blink start text
	blink_timer += delta
	if blink_timer >= TEXT_BLINK_RATE:
		blink_timer = 0.0
		text_visible = not text_visible
		start_text_sprite.visible = text_visible


func _update_waterfall() -> void:
	## Update waterfall sprites to create flowing animation
	# Each row shows a different frame, offset by row index
	for i in range(waterfall_sprites.size()):
		var frame_index := (waterfall_frame + i) % 3
		waterfall_sprites[i].region_rect = WATERFALL_FRAMES[frame_index]


func _unhandled_input(event: InputEvent) -> void:
	# Accept Start or Attack to proceed
	if event.is_action_pressed("start") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_transition_to_file_select()


func _transition_to_file_select() -> void:
	## Change scene to file select screen
	get_tree().change_scene_to_file("res://scenes/ui/file_select.tscn")
