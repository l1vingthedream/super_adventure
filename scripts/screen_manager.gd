extends Node2D
## Manages the overworld tilemap and screen-based camera transitions
## in the style of the original Legend of Zelda.

# Screen configuration (matches original Zelda)
const TILE_SIZE := 16
const SCREEN_WIDTH_TILES := 16
const SCREEN_HEIGHT_TILES := 11
const SCREEN_WIDTH_PX := SCREEN_WIDTH_TILES * TILE_SIZE  # 256
const SCREEN_HEIGHT_PX := SCREEN_HEIGHT_TILES * TILE_SIZE  # 176

# Tileset configuration - tiles arranged in grid
const TILESET_COLUMNS := 63
const TILESET_ROWS := 62

# Transition settings
const TRANSITION_SPEED := 200.0  # pixels per second

# Node references
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D

# State
var current_screen := Vector2i(7, 7)  # Start at screen 7,7 (like original Zelda)
var map_data: Array = []
var map_width: int = 0
var map_height: int = 0
var is_transitioning := false
var transition_target := Vector2.ZERO
var transition_direction := Vector2i.ZERO
var transitioning_player: CharacterBody2D = null
var player_transition_offset := Vector2.ZERO  # Offset from camera center during transition


func _ready() -> void:
	setup_tileset()
	load_tilemap_data()
	populate_tilemap()
	center_camera_on_screen(current_screen)


func setup_tileset() -> void:
	## Create the TileSet programmatically with all tiles defined
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Load the tileset texture
	var texture := load("res://assets/tileset.png") as Texture2D
	if not texture:
		push_error("Failed to load tileset.png")
		return

	# Create atlas source
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Create a tile for each position in the atlas
	for y in range(TILESET_ROWS):
		for x in range(TILESET_COLUMNS):
			var coords := Vector2i(x, y)
			atlas.create_tile(coords)

	# Add atlas to tileset
	tileset.add_source(atlas, 0)

	# Assign to tilemap
	tilemap.tile_set = tileset
	print("TileSet created with %d tiles" % (TILESET_COLUMNS * TILESET_ROWS))


func load_tilemap_data() -> void:
	## Load tilemap data from the generated JSON file
	var file := FileAccess.open("res://assets/overworld.json", FileAccess.READ)
	if not file:
		push_error("Failed to load overworld.json")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("Failed to parse overworld.json: " + json.get_error_message())
		return

	var data: Dictionary = json.data

	# Get map dimensions
	map_width = data.get("width", 0)
	map_height = data.get("height", 0)

	# Get tile data from first layer
	var layers: Array = data.get("layers", [])
	if layers.size() > 0:
		map_data = layers[0].get("data", [])

	print("Loaded tilemap: %dx%d tiles (%d total)" % [map_width, map_height, map_data.size()])


func populate_tilemap() -> void:
	## Populate the TileMapLayer with tiles from the loaded data
	if map_data.is_empty():
		push_error("No map data to populate")
		return

	for y in range(map_height):
		for x in range(map_width):
			var index := y * map_width + x
			if index >= map_data.size():
				continue

			var tile_id: int = map_data[index]
			if tile_id <= 0:
				continue  # Empty tile

			# Convert from Tiled 1-based ID to atlas coords
			# Tile ID 1 = atlas position (0, 0)
			var atlas_id := tile_id - 1
			var atlas_x := atlas_id % TILESET_COLUMNS
			var atlas_y := atlas_id / TILESET_COLUMNS

			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(atlas_x, atlas_y))

	print("Populated %d tiles" % (map_width * map_height))


func center_camera_on_screen(screen: Vector2i) -> void:
	## Center the camera on a specific screen
	camera.position = Vector2(
		screen.x * SCREEN_WIDTH_PX + SCREEN_WIDTH_PX / 2.0,
		screen.y * SCREEN_HEIGHT_PX + SCREEN_HEIGHT_PX / 2.0
	)


func get_screen_from_position(pos: Vector2) -> Vector2i:
	## Get the screen coordinates for a world position
	return Vector2i(
		int(pos.x / SCREEN_WIDTH_PX),
		int(pos.y / SCREEN_HEIGHT_PX)
	)


func can_transition_to(screen: Vector2i) -> bool:
	## Check if the target screen is within map bounds
	var screens_wide := map_width / SCREEN_WIDTH_TILES
	var screens_tall := map_height / SCREEN_HEIGHT_TILES

	return screen.x >= 0 and screen.x < screens_wide and screen.y >= 0 and screen.y < screens_tall


func start_player_transition(new_screen: Vector2i, direction: Vector2i, player: CharacterBody2D) -> void:
	## Start a screen transition triggered by player movement
	if is_transitioning:
		return

	is_transitioning = true
	current_screen = new_screen
	transition_direction = direction
	transitioning_player = player

	transition_target = Vector2(
		new_screen.x * SCREEN_WIDTH_PX + SCREEN_WIDTH_PX / 2.0,
		new_screen.y * SCREEN_HEIGHT_PX + SCREEN_HEIGHT_PX / 2.0
	)

	# Reposition player to opposite edge of new screen
	reposition_player_for_transition(player, direction)


func reposition_player_for_transition(player: CharacterBody2D, direction: Vector2i) -> void:
	## Move player to the entry edge of the new screen
	var new_pos := player.global_position

	# Small offset to place player just inside the new screen
	var edge_offset := 16.0

	if direction.x > 0:  # Moving right
		new_pos.x = current_screen.x * SCREEN_WIDTH_PX + edge_offset
	elif direction.x < 0:  # Moving left
		new_pos.x = (current_screen.x + 1) * SCREEN_WIDTH_PX - edge_offset
	elif direction.y > 0:  # Moving down
		new_pos.y = current_screen.y * SCREEN_HEIGHT_PX + edge_offset
	elif direction.y < 0:  # Moving up
		new_pos.y = (current_screen.y + 1) * SCREEN_HEIGHT_PX - edge_offset

	player.global_position = new_pos

	# Calculate offset from camera center for smooth movement
	player_transition_offset = player.global_position - transition_target


func transition_to_screen(new_screen: Vector2i) -> void:
	## Start a smooth screen transition (camera only, no player repositioning)
	if is_transitioning:
		return

	if new_screen == current_screen:
		return

	is_transitioning = true
	current_screen = new_screen
	transition_target = Vector2(
		new_screen.x * SCREEN_WIDTH_PX + SCREEN_WIDTH_PX / 2.0,
		new_screen.y * SCREEN_HEIGHT_PX + SCREEN_HEIGHT_PX / 2.0
	)


func _process(delta: float) -> void:
	if is_transitioning:
		var direction := (transition_target - camera.position).normalized()
		var distance := camera.position.distance_to(transition_target)
		var move_amount := TRANSITION_SPEED * delta

		if distance <= move_amount:
			camera.position = transition_target
			# Transition complete - position player at final spot
			if transitioning_player:
				transitioning_player.global_position = transition_target + player_transition_offset
				transitioning_player = null
			is_transitioning = false
			transition_direction = Vector2i.ZERO
		else:
			camera.position += direction * move_amount
			# Move player along with camera
			if transitioning_player:
				transitioning_player.global_position = camera.position + player_transition_offset


# Debug controls removed - player movement now handles screen transitions
# To manually test transitions, use: transition_to_screen(Vector2i(x, y))
