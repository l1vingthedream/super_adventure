extends CharacterBody2D
class_name Leever
## Leever - burrowing enemy that emerges from the ground near the player,
## walks toward them, then burrows again. Invulnerable while underground.
## Red (2 HP, slow) and Blue (4 HP, faster) variants.

const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0
const EMERGE_DURATION := 0.5
const BURROW_DURATION := 0.5
const BURIED_TIME_MIN := 1.5
const BURIED_TIME_MAX := 3.0
const REPOSITION_RANGE := 64.0  # How far from player to emerge
const MAX_REPOSITION_ATTEMPTS := 10
const SAND_TILES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 3), Vector2i(1, 4), Vector2i(3, 3),
	Vector2i(3, 10), Vector2i(5, 5), Vector2i(5, 8), Vector2i(5, 9)
]

enum LeeverColor { RED, BLUE }
enum State { BURIED, EMERGING, WALKING, BURROWING }

@export var color: LeeverColor = LeeverColor.RED

var health := 2
var move_speed := 30.0
var walk_duration := 2.0
var state := State.BURIED
var state_timer := 0.0
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0
var move_direction := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape
@onready var contact_shape: CollisionShape2D = $ContactDamage/ContactShape


func _ready() -> void:
	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)

	# Configure stats by color
	if color == LeeverColor.BLUE:
		health = 4
		move_speed = 45.0
		walk_duration = 3.0

	# Start buried
	_enter_buried()
	state_timer = randf_range(0.5, 1.5)  # Shorter initial delay


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Handle damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		palette_frame = 1 + int(damage_flash_timer * DAMAGE_FLASH_SPEED) % 3
		sprite.material.set_shader_parameter("palette_frame", palette_frame)
		if damage_flash_timer <= 0:
			palette_frame = 0
			sprite.material.set_shader_parameter("palette_frame", 0)

	state_timer -= delta

	match state:
		State.BURIED:
			if state_timer <= 0:
				_reposition_near_player()
				_enter_emerging()
		State.EMERGING:
			if state_timer <= 0:
				_enter_walking()
		State.WALKING:
			_update_move_direction()
			velocity = move_direction * move_speed
			move_and_slide()
			if state_timer <= 0:
				_enter_burrowing()
		State.BURROWING:
			if state_timer <= 0:
				_enter_buried()


func _enter_buried() -> void:
	state = State.BURIED
	state_timer = randf_range(BURIED_TIME_MIN, BURIED_TIME_MAX)
	sprite.visible = false
	_set_collision_enabled(false)


func _enter_emerging() -> void:
	state = State.EMERGING
	state_timer = EMERGE_DURATION
	sprite.visible = true
	_set_collision_enabled(false)  # Still invulnerable while emerging
	var prefix := "red" if color == LeeverColor.RED else "blue"
	sprite.play(prefix + "_emerge")


func _enter_walking() -> void:
	state = State.WALKING
	state_timer = walk_duration
	_set_collision_enabled(true)
	var prefix := "red" if color == LeeverColor.RED else "blue"
	sprite.play(prefix + "_walk")


func _enter_burrowing() -> void:
	state = State.BURROWING
	state_timer = BURROW_DURATION
	_set_collision_enabled(false)  # Invulnerable while burrowing
	var prefix := "red" if color == LeeverColor.RED else "blue"
	sprite.play(prefix + "_burrow")


func _set_collision_enabled(enabled: bool) -> void:
	body_collision.set_deferred("disabled", not enabled)
	hitbox_shape.set_deferred("disabled", not enabled)
	contact_shape.set_deferred("disabled", not enabled)


func _reposition_near_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().get_node_or_null("../Player")
	if not player:
		return

	var tilemap := _get_tilemap()

	for i in MAX_REPOSITION_ATTEMPTS:
		var offset := Vector2(
			randf_range(-REPOSITION_RANGE, REPOSITION_RANGE),
			randf_range(-REPOSITION_RANGE, REPOSITION_RANGE)
		)
		var target_pos: Vector2 = player.global_position + offset
		if tilemap and _is_sand_tile(tilemap, target_pos):
			global_position = target_pos
			return

	# Fallback: stay at current position if no sand tile found
	pass


func _get_tilemap() -> TileMapLayer:
	# enemies_container is child of screen_manager, tilemap is sibling
	var screen_manager = get_parent().get_parent()
	if screen_manager:
		return screen_manager.get_node_or_null("TileMapLayer") as TileMapLayer
	return null


func _is_sand_tile(tilemap: TileMapLayer, pos: Vector2) -> bool:
	var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(pos))
	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
	# Atlas coords are (col, row) in the tileset
	# SAND_TILES uses (row, col) format from user, so compare as (row, col)
	var tile_row_col := Vector2i(atlas_coords.y, atlas_coords.x)
	return tile_row_col in SAND_TILES


func _update_move_direction() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().get_node_or_null("../Player")
	if player:
		var diff: Vector2 = player.global_position - global_position
		# Move in cardinal direction toward player
		if abs(diff.x) > abs(diff.y):
			move_direction = Vector2(sign(diff.x), 0)
		else:
			move_direction = Vector2(0, sign(diff.y))
	else:
		move_direction = Vector2.DOWN


func take_damage(amount: int) -> void:
	if is_dead or state != State.WALKING:
		return
	health -= amount
	damage_flash_timer = DAMAGE_FLASH_DURATION
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	var death_effect = preload("res://scenes/enemies/enemy_death.tscn").instantiate()
	death_effect.global_position = global_position
	get_parent().add_child(death_effect)
	DropSystem.spawn_drop(global_position, get_parent())
	queue_free()


func _on_contact_damage_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
