extends Node2D
## Manages the White Sword cave where the player receives the white sword.
## Requires 5 hearts to receive the sword.

const TILE_SIZE := 16
const SCREEN_WIDTH_TILES := 16
const SCREEN_HEIGHT_TILES := 11
const _SCREEN_WIDTH_PX := SCREEN_WIDTH_TILES * TILE_SIZE  # 256
const _SCREEN_HEIGHT_PX := SCREEN_HEIGHT_TILES * TILE_SIZE  # 176
const HUD_HEIGHT := 56

# Tileset configuration
const TILESET_COLUMNS := 16
const TILESET_ROWS := 6

# Cave tile layout (same layout as old man cave)
# Tiles: 91=wall, 92=door frame, 93=exit floor, 96=interior floor
const CAVE_LAYOUT := [
	[91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91],
	[91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 91, 91],
	[91, 91, 92, 92, 92, 92, 92, 96, 96, 92, 92, 92, 92, 92, 91, 91],
	[93, 93, 93, 93, 93, 93, 93, 96, 96, 93, 93, 93, 93, 93, 93, 93],
]

# Walkable tiles in cave (0-based atlas IDs, not 1-based Tiled IDs)
# 93 (1-based) = 92 (0-based), 96 (1-based) = 95 (0-based)
const WALKABLE_TILES := [92, 95]

# Node references
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = $Player
@onready var old_man: Node2D = $WhiteSwordOldMan
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var sword_pickup: Area2D = $SwordPickup
@onready var hud: CanvasLayer = $HUD

# State
var player_entered := false  # True once player has moved up from entrance

# Properties expected by player.gd (screen_manager interface)
var is_transitioning := false

# Screen size exposed as instance variables for player.gd compatibility
# (player.clamp_to_screen accesses these as screen_manager.SCREEN_WIDTH_PX)
var SCREEN_WIDTH_PX := 256
var SCREEN_HEIGHT_PX := 176


func _ready() -> void:
	setup_tileset()
	populate_tilemap()
	center_camera()
	position_player_at_entrance()

	# Give old man reference to player
	if old_man and old_man.has_method("set_player"):
		old_man.set_player(player)

	# Connect HUD to player if method exists
	if hud and hud.has_method("connect_to_player"):
		hud.connect_to_player(player)


func setup_tileset() -> void:
	## Create the TileSet programmatically (same pattern as overworld)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add physics layer for tile collisions
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)

	# Load the tileset texture
	var texture := load("res://assets/overworld_tileset.png") as Texture2D
	if not texture:
		push_error("Failed to load overworld_tileset.png")
		return

	# Create atlas source
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Create all tiles
	for y in range(TILESET_ROWS):
		for x in range(TILESET_COLUMNS):
			atlas.create_tile(Vector2i(x, y))

	tileset.add_source(atlas, 0)
	tilemap.tile_set = tileset

	# Add collision to non-walkable tiles
	for y in range(TILESET_ROWS):
		for x in range(TILESET_COLUMNS):
			var coords := Vector2i(x, y)
			var tile_id: int = y * TILESET_COLUMNS + x

			if tile_id not in WALKABLE_TILES:
				var tile_data := atlas.get_tile_data(coords, 0)
				if tile_data:
					_add_full_tile_collision(tile_data)


func _add_full_tile_collision(tile_data: TileData) -> void:
	var half := TILE_SIZE / 2.0
	var collision_polygon := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, collision_polygon)


func populate_tilemap() -> void:
	## Populate the TileMapLayer with cave tiles
	for y in range(SCREEN_HEIGHT_TILES):
		for x in range(SCREEN_WIDTH_TILES):
			var tile_id: int = CAVE_LAYOUT[y][x]
			if tile_id <= 0:
				continue

			# Convert from 1-based ID to atlas coords
			var atlas_id := tile_id - 1
			var atlas_x := atlas_id % TILESET_COLUMNS
			var atlas_y := atlas_id / TILESET_COLUMNS

			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(atlas_x, atlas_y))


func center_camera() -> void:
	## Center camera on the cave (accounting for HUD offset)
	camera.position = Vector2(
		SCREEN_WIDTH_PX / 2.0,
		SCREEN_HEIGHT_PX / 2.0 - HUD_HEIGHT / 2.0
	)


func position_player_at_entrance() -> void:
	## Position player at bottom-center of cave (entrance)
	player.global_position = Vector2(
		SCREEN_WIDTH_PX / 2.0,  # Center X (column 7-8)
		(SCREEN_HEIGHT_TILES - 1) * TILE_SIZE  # Bottom row
	)


func _physics_process(_delta: float) -> void:
	if not player:
		return

	# Track when player has moved up from entrance (prevents immediate exit)
	var entrance_y := (SCREEN_HEIGHT_TILES - 1) * TILE_SIZE  # Row 10 = y 160
	if not player_entered and player.global_position.y < entrance_y - 8:
		player_entered = true

	# Check if player exits the cave (walks back to bottom edge after entering)
	if player_entered and player.global_position.y >= SCREEN_HEIGHT_PX - 8:
		exit_cave()


func exit_cave() -> void:
	## Return to the overworld at the white sword cave screen
	player_entered = false  # Prevent multiple triggers

	# Set return state in GameManager
	GameManager.returning_from_cave = true
	GameManager.cave_exit_screen = Vector2i(10, 0)  # Screen col=10, row=0
	GameManager.cave_exit_tile = Vector2i(2, 1)  # Tile col=2, row=1

	get_tree().change_scene_to_file("res://scenes/overworld.tscn")


func show_sword_pickup() -> void:
	## Called by WhiteSwordOldMan after dialogue completes
	if sword_pickup:
		sword_pickup.visible = true
		sword_pickup.monitoring = true


# =============================================================================
# Screen Manager Interface (for player.gd compatibility)
# =============================================================================

func get_screen_from_position(_pos: Vector2) -> Vector2i:
	## Caves are single-screen, always return (0, 0)
	return Vector2i(0, 0)


func check_cave_entrance(_player_pos: Vector2) -> bool:
	## No cave entrances inside caves
	return false


func can_transition_to(_screen: Vector2i) -> bool:
	## No screen transitions in caves
	return false


func start_player_transition(_new_screen: Vector2i, _direction: Vector2i, _player: CharacterBody2D) -> void:
	## No screen transitions in caves - handled by exit logic instead
	pass
