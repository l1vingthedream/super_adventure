extends Node2D
## Secret item cave revealed by bombing a tile on screen (11,1).
## Old man says "TAKE ANY ONE YOU WANT" — item pickups to be added later.

const TILE_SIZE := 16
const SCREEN_WIDTH_TILES := 16
const SCREEN_HEIGHT_TILES := 11
const _SCREEN_WIDTH_PX := SCREEN_WIDTH_TILES * TILE_SIZE  # 256
const _SCREEN_HEIGHT_PX := SCREEN_HEIGHT_TILES * TILE_SIZE  # 176
const HUD_HEIGHT := 56

# Tileset configuration
const TILESET_COLUMNS := 16
const TILESET_ROWS := 6

# Cave tile layout (same as old man cave)
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

# Walkable tiles in cave (0-based atlas IDs)
# 93 (1-based) = 92 (0-based), 96 (1-based) = 95 (0-based)
const WALKABLE_TILES := [92, 95]

# Node references
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = $Player
@onready var old_man: Node2D = $SecretCaveOldMan
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var hud: CanvasLayer = $HUD

# State
var player_entered := false

# Properties expected by player.gd (screen_manager interface)
var is_transitioning := false
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

	# Connect HUD to player
	if hud and hud.has_method("connect_to_player"):
		hud.connect_to_player(player)


func setup_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)

	var texture := load("res://assets/overworld_tileset.png") as Texture2D
	if not texture:
		push_error("Failed to load overworld_tileset.png")
		return

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for y in range(TILESET_ROWS):
		for x in range(TILESET_COLUMNS):
			atlas.create_tile(Vector2i(x, y))

	tileset.add_source(atlas, 0)
	tilemap.tile_set = tileset

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
	for y in range(SCREEN_HEIGHT_TILES):
		for x in range(SCREEN_WIDTH_TILES):
			var tile_id: int = CAVE_LAYOUT[y][x]
			if tile_id <= 0:
				continue
			var atlas_id := tile_id - 1
			var atlas_x := atlas_id % TILESET_COLUMNS
			var atlas_y := atlas_id / TILESET_COLUMNS
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(atlas_x, atlas_y))


func center_camera() -> void:
	camera.position = Vector2(
		SCREEN_WIDTH_PX / 2.0,
		SCREEN_HEIGHT_PX / 2.0 - HUD_HEIGHT / 2.0
	)


func position_player_at_entrance() -> void:
	player.global_position = Vector2(
		SCREEN_WIDTH_PX / 2.0,
		(SCREEN_HEIGHT_TILES - 1) * TILE_SIZE
	)


func _physics_process(_delta: float) -> void:
	if not player:
		return

	var entrance_y := (SCREEN_HEIGHT_TILES - 1) * TILE_SIZE
	if not player_entered and player.global_position.y < entrance_y - 8:
		player_entered = true

	if player_entered and player.global_position.y >= SCREEN_HEIGHT_PX - 8:
		exit_cave()


func exit_cave() -> void:
	player_entered = false

	GameManager.returning_from_cave = true
	GameManager.cave_exit_screen = Vector2i(11, 7)
	GameManager.cave_exit_tile = Vector2i(9, 1)

	get_tree().change_scene_to_file("res://scenes/overworld.tscn")


# =============================================================================
# Screen Manager Interface (for player.gd compatibility)
# =============================================================================

func get_screen_from_position(_pos: Vector2) -> Vector2i:
	return Vector2i(0, 0)


func check_cave_entrance(_player_pos: Vector2) -> bool:
	return false


func can_transition_to(_screen: Vector2i) -> bool:
	return false


func start_player_transition(_new_screen: Vector2i, _direction: Vector2i, _player: CharacterBody2D) -> void:
	pass
