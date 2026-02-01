extends Node2D
## Manages the overworld tilemap and screen-based camera transitions
## in the style of the original Legend of Zelda.

# Screen configuration (matches original Zelda)
const TILE_SIZE := 16
const SCREEN_WIDTH_TILES := 16
const SCREEN_HEIGHT_TILES := 11
const SCREEN_WIDTH_PX := SCREEN_WIDTH_TILES * TILE_SIZE  # 256
const SCREEN_HEIGHT_PX := SCREEN_HEIGHT_TILES * TILE_SIZE  # 176
const HUD_HEIGHT := 56  # Pixels reserved for HUD at top of screen

# Tileset configuration - tiles arranged in grid
const TILESET_COLUMNS := 16
const TILESET_ROWS := 6

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

# Collision data
var walkable_tiles: Array = []  # Tile IDs that player can walk through

# Enemy spawning
var enemies_container: Node2D

# Rock spawner
var rock_spawn_timer := 0.0
var rock_spawn_interval := 0.0
var is_rock_screen := false
const ROCK_SPAWN_MIN := 0.8
const ROCK_SPAWN_MAX := 2.0
const ROCK_SCREENS := [Vector2i(5, 1), Vector2i(6, 1)]  # Mountain screens

# HUD reference
var hud: CanvasLayer

# Cave entrance definitions: screen -> { tile position within screen, destination scene }
# Tile positions use 0-based indexing (col, row)
var cave_entrances := {
	Vector2i(7, 7): {  # Starting screen
		"tile": Vector2i(4, 1),  # Col 5, Row 2 in 1-based = Col 4, Row 1 in 0-based
		"destination": "res://scenes/caves/old_man_cave.tscn"
	},
	Vector2i(10, 0): {  # White sword cave screen (col=10, row=0)
		"tile": Vector2i(2, 1),  # Tile col=2, row=1
		"destination": "res://scenes/caves/white_sword_cave.tscn"
	},
	Vector2i(15, 6): {  # Merchant cave screen (col=15, row=6)
		"tile": Vector2i(3, 1),  # Tile col=3, row=1
		"destination": "res://scenes/caves/merchant_cave.tscn"
	}
}

# Bombable tile definitions: screen -> array of bombable tile data
# Each entry: { tile: tile pos in screen, replacement: atlas coords, cave: destination (optional) }
var bombable_tiles := {
	Vector2i(11, 7): [
		{
			"tile": Vector2i(9, 1),
			"replacement": Vector2i(8, 0),
			"cave": "res://scenes/caves/secret_item_cave.tscn"
		}
	]
}

# Signal for cave transitions
signal entering_cave(destination: String)


func _ready() -> void:
	load_collision_data()
	setup_tileset()
	load_tilemap_data()
	populate_tilemap()
	_restore_revealed_tiles()
	center_camera_on_screen(current_screen)

	# Create container for enemies
	enemies_container = Node2D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	# Spawn enemies for starting screen
	_spawn_enemies_for_screen(current_screen)

	# Set up HUD connections after scene is ready
	call_deferred("_setup_hud")

	# Handle return from cave/interior
	call_deferred("_handle_cave_return")

	# Debug overlay
	if GameManager.DEBUG_INPUTS_ENABLED:
		var debug_hud = preload("res://scenes/ui/debug_hud.tscn").instantiate()
		add_child(debug_hud)


func load_collision_data() -> void:
	## Load tile collision definitions from JSON
	var file := FileAccess.open("res://assets/tile_collision_data.json", FileAccess.READ)
	if not file:
		push_warning("No collision data file found - all tiles will be walkable")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("Failed to parse tile_collision_data.json: " + json.get_error_message())
		return

	var data: Dictionary = json.data
	var raw_tiles: Array = data.get("walkable_tiles", [])
	# Convert to integers (JSON parses numbers as floats)
	walkable_tiles = []
	for tile in raw_tiles:
		walkable_tiles.append(int(tile))
	print("Loaded collision data: %d walkable tiles defined" % walkable_tiles.size())


func setup_tileset() -> void:
	## Create the TileSet programmatically with all tiles defined
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add physics layer for tile collisions (layer 1 = world)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)  # Tiles are on layer 1
	tileset.set_physics_layer_collision_mask(0, 0)   # Tiles don't detect others

	# Load the tileset texture
	var texture := load("res://assets/overworld_tileset.png") as Texture2D
	if not texture:
		push_error("Failed to load overworld_tileset.png")
		return

	# Create atlas source
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Create all tiles first
	for y in range(TILESET_ROWS):
		for x in range(TILESET_COLUMNS):
			atlas.create_tile(Vector2i(x, y))

	# Add atlas to tileset BEFORE setting collision data
	tileset.add_source(atlas, 0)

	# Assign tileset to tilemap
	tilemap.tile_set = tileset

	# NOW add collision shapes (after tileset is assigned)
	var solid_count := 0
	for y in range(TILESET_ROWS):
		for x in range(TILESET_COLUMNS):
			var coords := Vector2i(x, y)
			var tile_id: int = y * TILESET_COLUMNS + x

			# Add collision to non-walkable tiles
			if tile_id not in walkable_tiles:
				var tile_data := atlas.get_tile_data(coords, 0)
				if tile_data:
					_add_full_tile_collision(tile_data)
					solid_count += 1

	print("TileSet created with %d tiles (%d solid, %d walkable)" % [TILESET_COLUMNS * TILESET_ROWS, solid_count, walkable_tiles.size()])
	print("Walkable tile IDs: ", walkable_tiles)


func _add_full_tile_collision(tile_data: TileData) -> void:
	## Add a full-tile collision polygon to the given tile
	## Coordinates are relative to tile center (half tile size offset)
	var half := TILE_SIZE / 2.0
	var collision_polygon := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, collision_polygon)


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
	## Center the camera on a specific screen (accounting for HUD offset)
	# Camera Y is shifted up (negative) so game content appears below the HUD
	camera.position = Vector2(
		screen.x * SCREEN_WIDTH_PX + SCREEN_WIDTH_PX / 2.0,
		screen.y * SCREEN_HEIGHT_PX + SCREEN_HEIGHT_PX / 2.0 - HUD_HEIGHT / 2.0
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
		new_screen.y * SCREEN_HEIGHT_PX + SCREEN_HEIGHT_PX / 2.0 - HUD_HEIGHT / 2.0
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
		new_screen.y * SCREEN_HEIGHT_PX + SCREEN_HEIGHT_PX / 2.0 - HUD_HEIGHT / 2.0
	)


func _process(delta: float) -> void:
	# Rock spawner
	if is_rock_screen and not is_transitioning:
		rock_spawn_timer -= delta
		if rock_spawn_timer <= 0:
			_spawn_falling_rock()
			rock_spawn_timer = randf_range(ROCK_SPAWN_MIN, ROCK_SPAWN_MAX)

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
			# Spawn enemies for new screen
			_spawn_enemies_for_screen(current_screen)
			# Update HUD minimap
			if hud:
				hud.update_minimap(current_screen)
		else:
			camera.position += direction * move_amount
			# Move player along with camera
			if transitioning_player:
				transitioning_player.global_position = camera.position + player_transition_offset


# Debug controls removed - player movement now handles screen transitions
# To manually test transitions, use: transition_to_screen(Vector2i(x, y))


# =============================================================================
# Enemy Spawning
# =============================================================================

func _spawn_enemies_for_screen(screen: Vector2i) -> void:
	## Clear existing enemies and spawn new ones for the given screen
	_clear_enemies()

	# Check if this is a rock-spawning screen
	is_rock_screen = screen in ROCK_SCREENS
	if is_rock_screen:
		rock_spawn_timer = randf_range(0.5, 1.0)  # Short initial delay

	# Calculate screen bounds for spawning
	var screen_left := screen.x * SCREEN_WIDTH_PX
	var screen_top := screen.y * SCREEN_HEIGHT_PX

	# For testing, spawn Octorok on screen (7, 6) - one screen up from start
	if screen == Vector2i(7, 6):
		_spawn_octorok(Vector2(screen_left + 128, screen_top + 88))

	# Spawn two Octoroks on screen (7, 5) - two screens up from start
	if screen == Vector2i(7, 5):
		_spawn_octorok(Vector2(screen_left + 80, screen_top + 60))
		_spawn_octorok(Vector2(screen_left + 176, screen_top + 100))

	# Spawn 4 red Tektites on screen (6, 7)
	if screen == Vector2i(6, 7):
		_spawn_tektite(Vector2(screen_left + 64, screen_top + 48), Tektite.TektiteColor.RED)
		_spawn_tektite(Vector2(screen_left + 192, screen_top + 48), Tektite.TektiteColor.RED)
		_spawn_tektite(Vector2(screen_left + 64, screen_top + 128), Tektite.TektiteColor.RED)
		_spawn_tektite(Vector2(screen_left + 192, screen_top + 128), Tektite.TektiteColor.RED)

	# Spawn 4 blue Tektites on screen (9, 7)
	if screen == Vector2i(9, 7):
		_spawn_tektite(Vector2(screen_left + 64, screen_top + 48), Tektite.TektiteColor.BLUE)
		_spawn_tektite(Vector2(screen_left + 192, screen_top + 48), Tektite.TektiteColor.BLUE)
		_spawn_tektite(Vector2(screen_left + 64, screen_top + 128), Tektite.TektiteColor.BLUE)
		_spawn_tektite(Vector2(screen_left + 192, screen_top + 128), Tektite.TektiteColor.BLUE)

	# Spawn Ghinis on graveyard screens
	if screen == Vector2i(0, 2):
		_spawn_ghini(Vector2(screen_left + 64, screen_top + 64))
		_spawn_ghini(Vector2(screen_left + 192, screen_top + 96))
		_spawn_ghini(Vector2(screen_left + 128, screen_top + 128))
	if screen == Vector2i(0, 3):
		_spawn_ghini(Vector2(screen_left + 80, screen_top + 56))
		_spawn_ghini(Vector2(screen_left + 176, screen_top + 112))
		_spawn_ghini(Vector2(screen_left + 128, screen_top + 80))
	if screen == Vector2i(0, 4):
		_spawn_ghini(Vector2(screen_left + 96, screen_top + 72))
		_spawn_ghini(Vector2(screen_left + 160, screen_top + 120))
	if screen == Vector2i(1, 2):
		_spawn_ghini(Vector2(screen_left + 64, screen_top + 88))
		_spawn_ghini(Vector2(screen_left + 192, screen_top + 64))
		_spawn_ghini(Vector2(screen_left + 128, screen_top + 128))
	if screen == Vector2i(1, 3):
		_spawn_ghini(Vector2(screen_left + 80, screen_top + 64))
		_spawn_ghini(Vector2(screen_left + 176, screen_top + 104))
	if screen == Vector2i(1, 4):
		_spawn_ghini(Vector2(screen_left + 96, screen_top + 72))
		_spawn_ghini(Vector2(screen_left + 192, screen_top + 112))
		_spawn_ghini(Vector2(screen_left + 128, screen_top + 56))

	# Spawn Leevers on desert/sand screens
	if screen == Vector2i(11, 7):
		_spawn_leever(Vector2(screen_left + 80, screen_top + 64), Leever.LeeverColor.RED)
		_spawn_leever(Vector2(screen_left + 176, screen_top + 112), Leever.LeeverColor.RED)
		_spawn_leever(Vector2(screen_left + 128, screen_top + 88), Leever.LeeverColor.RED)
	if screen == Vector2i(12, 7):
		_spawn_leever(Vector2(screen_left + 64, screen_top + 72), Leever.LeeverColor.RED)
		_spawn_leever(Vector2(screen_left + 192, screen_top + 96), Leever.LeeverColor.RED)
	if screen == Vector2i(13, 7):
		_spawn_leever(Vector2(screen_left + 96, screen_top + 80), Leever.LeeverColor.BLUE)
		_spawn_leever(Vector2(screen_left + 160, screen_top + 104), Leever.LeeverColor.BLUE)
		_spawn_leever(Vector2(screen_left + 64, screen_top + 56), Leever.LeeverColor.BLUE)
	if screen == Vector2i(1, 7):
		_spawn_leever(Vector2(screen_left + 80, screen_top + 72), Leever.LeeverColor.RED)
		_spawn_leever(Vector2(screen_left + 176, screen_top + 96), Leever.LeeverColor.RED)

	# Spawn Peahats
	if screen == Vector2i(5, 7):
		_spawn_peahat(Vector2(screen_left + 64, screen_top + 64))
		_spawn_peahat(Vector2(screen_left + 192, screen_top + 112))
		_spawn_peahat(Vector2(screen_left + 128, screen_top + 80))
	if screen == Vector2i(4, 7):
		_spawn_peahat(Vector2(screen_left + 96, screen_top + 56))
		_spawn_peahat(Vector2(screen_left + 160, screen_top + 120))
	if screen == Vector2i(0, 7):
		_spawn_peahat(Vector2(screen_left + 80, screen_top + 72))
		_spawn_peahat(Vector2(screen_left + 176, screen_top + 104))
	if screen == Vector2i(0, 6):
		_spawn_peahat(Vector2(screen_left + 64, screen_top + 64))
		_spawn_peahat(Vector2(screen_left + 192, screen_top + 112))
		_spawn_peahat(Vector2(screen_left + 128, screen_top + 88))
	if screen == Vector2i(9, 5):
		_spawn_peahat(Vector2(screen_left + 96, screen_top + 60))
		_spawn_peahat(Vector2(screen_left + 160, screen_top + 116))

	# Spawn Moblins
	if screen == Vector2i(8, 5):
		_spawn_moblin(Vector2(screen_left + 80, screen_top + 64), Moblin.MoblinColor.RED)
		_spawn_moblin(Vector2(screen_left + 176, screen_top + 112), Moblin.MoblinColor.RED)
	if screen == Vector2i(10, 5):
		_spawn_moblin(Vector2(screen_left + 64, screen_top + 72), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 192, screen_top + 96), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 128, screen_top + 56), Moblin.MoblinColor.BLUE)
	if screen == Vector2i(1, 7):
		_spawn_moblin(Vector2(screen_left + 80, screen_top + 72), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 176, screen_top + 104), Moblin.MoblinColor.BLUE)
	if screen == Vector2i(2, 7):
		_spawn_moblin(Vector2(screen_left + 64, screen_top + 64), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 192, screen_top + 112), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 128, screen_top + 88), Moblin.MoblinColor.BLUE)
	if screen == Vector2i(3, 7):
		_spawn_moblin(Vector2(screen_left + 96, screen_top + 56), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 160, screen_top + 120), Moblin.MoblinColor.BLUE)
	if screen == Vector2i(1, 6):
		_spawn_moblin(Vector2(screen_left + 80, screen_top + 80), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 176, screen_top + 96), Moblin.MoblinColor.BLUE)
	if screen == Vector2i(2, 6):
		_spawn_moblin(Vector2(screen_left + 64, screen_top + 68), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 192, screen_top + 108), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 128, screen_top + 80), Moblin.MoblinColor.BLUE)
	if screen == Vector2i(1, 5):
		_spawn_moblin(Vector2(screen_left + 96, screen_top + 64), Moblin.MoblinColor.BLUE)
		_spawn_moblin(Vector2(screen_left + 160, screen_top + 112), Moblin.MoblinColor.BLUE)

	# Scan for Armos statue tiles on this screen
	_scan_armos_tiles(screen)


func _spawn_octorok(pos: Vector2) -> void:
	## Spawn an Octorok at the given position
	var octorok = preload("res://scenes/enemies/octorok.tscn").instantiate()
	octorok.global_position = pos
	enemies_container.add_child(octorok)


func _spawn_tektite(pos: Vector2, tektite_color: Tektite.TektiteColor) -> void:
	## Spawn a Tektite at the given position with the specified color
	var tektite = preload("res://scenes/enemies/tektite.tscn").instantiate()
	tektite.color = tektite_color
	tektite.global_position = pos
	enemies_container.add_child(tektite)


const ARMOS_TILE_IDS: Array[int] = [25, 49, 78]  # 1-based Tiled IDs for Armos statue tiles

func _scan_armos_tiles(screen: Vector2i) -> void:
	## Scan the current screen for Armos tiles and spawn Armos enemies on them
	var screen_tile_x := screen.x * SCREEN_WIDTH_TILES
	var screen_tile_y := screen.y * SCREEN_HEIGHT_TILES

	for ty in SCREEN_HEIGHT_TILES:
		for tx in SCREEN_WIDTH_TILES:
			var map_x := screen_tile_x + tx
			var map_y := screen_tile_y + ty
			var index := map_y * map_width + map_x
			if index < map_data.size() and int(map_data[index]) in ARMOS_TILE_IDS:
				var world_pos := Vector2(map_x * TILE_SIZE + 8, map_y * TILE_SIZE + 8)
				var armos = preload("res://scenes/enemies/armos.tscn").instantiate()
				armos.global_position = world_pos
				armos.tile_cell = Vector2i(map_x, map_y)
				armos.activated.connect(_on_armos_activated)
				enemies_container.add_child(armos)


func _on_armos_activated(cell: Vector2i) -> void:
	## Replace an activated Armos tile with the tile directly above it
	var above_cell := Vector2i(cell.x, cell.y - 1)
	var above_atlas := tilemap.get_cell_atlas_coords(above_cell)
	tilemap.set_cell(cell, 0, above_atlas)


func _spawn_moblin(pos: Vector2, moblin_color: Moblin.MoblinColor) -> void:
	## Spawn a Moblin at the given position with the specified color
	var moblin = preload("res://scenes/enemies/moblin.tscn").instantiate()
	moblin.color = moblin_color
	moblin.global_position = pos
	enemies_container.add_child(moblin)


func _spawn_peahat(pos: Vector2) -> void:
	## Spawn a Peahat at the given position
	var peahat = preload("res://scenes/enemies/peahat.tscn").instantiate()
	peahat.global_position = pos
	enemies_container.add_child(peahat)


func _spawn_leever(pos: Vector2, leever_color: Leever.LeeverColor) -> void:
	## Spawn a Leever at the given position with the specified color
	var leever = preload("res://scenes/enemies/leever.tscn").instantiate()
	leever.color = leever_color
	leever.global_position = pos
	enemies_container.add_child(leever)


func _spawn_ghini(pos: Vector2) -> void:
	## Spawn a Ghini at the given position
	var ghini = preload("res://scenes/enemies/ghini.tscn").instantiate()
	ghini.global_position = pos
	enemies_container.add_child(ghini)


func _spawn_falling_rock() -> void:
	## Spawn a rock at a random X position at the top of the current screen
	var rock = preload("res://scenes/enemies/rock.tscn").instantiate()
	var screen_left := current_screen.x * SCREEN_WIDTH_PX
	var screen_top := current_screen.y * SCREEN_HEIGHT_PX
	var rand_x := screen_left + randf_range(16.0, 240.0)
	rock.global_position = Vector2(rand_x, screen_top - 8.0)
	rock.spawn_screen_top = screen_top
	rock.spawn_screen_left = screen_left
	enemies_container.add_child(rock)


func _clear_enemies() -> void:
	## Remove all enemies from the current screen
	for child in enemies_container.get_children():
		child.queue_free()


# =============================================================================
# Cave Entrance Detection
# =============================================================================

func check_cave_entrance(player_pos: Vector2) -> bool:
	## Check if player is standing on a cave entrance tile
	## Returns true if entering a cave (caller should stop movement)
	if is_transitioning:
		return false

	# Get current screen
	var screen := get_screen_from_position(player_pos)
	if screen not in cave_entrances:
		return false

	# Calculate tile position within the screen
	var screen_origin := Vector2(screen.x * SCREEN_WIDTH_PX, screen.y * SCREEN_HEIGHT_PX)
	var local_pos := player_pos - screen_origin
	var tile_pos := Vector2i(int(local_pos.x / TILE_SIZE), int(local_pos.y / TILE_SIZE))

	# Check if on cave entrance tile
	var cave_data: Dictionary = cave_entrances[screen]
	if tile_pos == cave_data["tile"]:
		_enter_cave(cave_data["destination"])
		return true

	return false


func _enter_cave(destination: String) -> void:
	## Transition to a cave scene
	entering_cave.emit(destination)
	get_tree().change_scene_to_file(destination)


# =============================================================================
# Bombable Tile Reveals
# =============================================================================

func try_bomb_reveal(explosion_pos: Vector2) -> void:
	## Check if a bomb explosion reveals any hidden tiles
	var screen := get_screen_from_position(explosion_pos)
	if screen not in bombable_tiles:
		return

	var screen_tile_x := screen.x * SCREEN_WIDTH_TILES
	var screen_tile_y := screen.y * SCREEN_HEIGHT_TILES

	for entry in bombable_tiles[screen]:
		var tile: Vector2i = entry["tile"]
		var map_cell := Vector2i(screen_tile_x + tile.x, screen_tile_y + tile.y)

		# Check if already revealed
		var reveal_key := "%d,%d" % [map_cell.x, map_cell.y]
		if reveal_key in GameManager.revealed_tiles:
			continue

		# Calculate tile center in world space
		var tile_center := Vector2(
			map_cell.x * TILE_SIZE + TILE_SIZE / 2.0,
			map_cell.y * TILE_SIZE + TILE_SIZE / 2.0
		)

		# Check if explosion is close enough (within 24px radius)
		if explosion_pos.distance_to(tile_center) <= 24.0:
			_reveal_tile(screen, entry, map_cell, reveal_key)


func _reveal_tile(screen: Vector2i, entry: Dictionary, map_cell: Vector2i, reveal_key: String) -> void:
	## Replace a bombable tile and optionally register a cave entrance
	var replacement: Vector2i = entry["replacement"]
	tilemap.set_cell(map_cell, 0, replacement)

	# Register cave entrance if defined
	if entry.has("cave"):
		cave_entrances[screen] = {
			"tile": entry["tile"],
			"destination": entry["cave"]
		}

	# Persist the reveal
	GameManager.revealed_tiles.append(reveal_key)
	print("Revealed bombable tile at map cell %s (screen %s)" % [map_cell, screen])


func _restore_revealed_tiles() -> void:
	## Re-apply any tiles that were previously revealed by bombs
	for screen_key in bombable_tiles:
		var screen: Vector2i = screen_key
		var screen_tile_x: int = screen.x * SCREEN_WIDTH_TILES
		var screen_tile_y: int = screen.y * SCREEN_HEIGHT_TILES
		for entry in bombable_tiles[screen]:
			var tile: Vector2i = entry["tile"]
			var map_cell := Vector2i(screen_tile_x + tile.x, screen_tile_y + tile.y)
			var reveal_key := "%d,%d" % [map_cell.x, map_cell.y]
			if reveal_key in GameManager.revealed_tiles:
				tilemap.set_cell(map_cell, 0, entry["replacement"])
				if entry.has("cave"):
					cave_entrances[screen] = {
						"tile": entry["tile"],
						"destination": entry["cave"]
					}


# =============================================================================
# HUD Setup
# =============================================================================

func _setup_hud() -> void:
	## Connect HUD to player and set initial state
	hud = get_node_or_null("HUD")
	if not hud:
		return

	# Connect to player for health updates and death handling
	var player = get_node_or_null("Player")
	if player:
		hud.connect_to_player(player)
		# Connect player death to show game over screen
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)

	# Set initial minimap position
	hud.update_minimap(current_screen)


func _handle_cave_return() -> void:
	## Position player at cave exit if returning from cave
	if not GameManager.returning_from_cave:
		return

	GameManager.returning_from_cave = false

	var player = get_node_or_null("Player")
	if not player:
		return

	# Set screen to cave exit screen
	current_screen = GameManager.cave_exit_screen
	center_camera_on_screen(current_screen)

	# Calculate player position at cave exit tile
	var tile := GameManager.cave_exit_tile
	var screen_origin := Vector2(current_screen.x * SCREEN_WIDTH_PX, current_screen.y * SCREEN_HEIGHT_PX)
	var tile_center := Vector2(
		tile.x * TILE_SIZE + TILE_SIZE / 2.0,
		tile.y * TILE_SIZE + TILE_SIZE + 8  # Position below cave entrance, facing down
	)
	player.global_position = screen_origin + tile_center

	# Set player facing down
	if player.has_method("set_facing_down"):
		player.set_facing_down()
	elif "facing" in player:
		player.facing = player.Direction.DOWN
		if player.has_method("update_animation"):
			player.update_animation()

	# Update minimap
	if hud:
		hud.update_minimap(current_screen)

	# Re-spawn enemies for the return screen
	_spawn_enemies_for_screen(current_screen)


func _on_player_died() -> void:
	## Show game over screen when player dies
	var game_over = preload("res://scenes/ui/game_over.tscn").instantiate()
	add_child(game_over)
