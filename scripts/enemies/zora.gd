extends CharacterBody2D
class_name Zora
## Zora - aquatic enemy that emerges from water, shoots fireballs at player,
## then submerges. Only appears on water tiles. Invulnerable while submerged.

const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0
const EMERGE_DURATION := 0.6
const SURFACE_DURATION := 1.5
const SUBMERGE_DURATION := 0.6
const SUBMERGED_TIME_MIN := 2.0
const SUBMERGED_TIME_MAX := 4.0
const REPOSITION_RANGE := 80.0
const MAX_REPOSITION_ATTEMPTS := 15

# Water tile atlas coords (row, col) format - matching Leever's SAND_TILES pattern
# Tile ID 39 (row=2, col=7) is the main water tile
const WATER_TILES: Array[Vector2i] = [
	Vector2i(2, 7)
]

enum State { SUBMERGED, EMERGING, SURFACE, SUBMERGING }

var health := 2
var state := State.SUBMERGED
var state_timer := 0.0
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0
var has_shot := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape
@onready var contact_shape: CollisionShape2D = $ContactDamage/ContactShape


func _ready() -> void:
	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)

	# Start submerged
	_enter_submerged()
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
		State.SUBMERGED:
			if state_timer <= 0:
				_reposition_near_player()
				_enter_emerging()
		State.EMERGING:
			if state_timer <= 0:
				_enter_surface()
		State.SURFACE:
			# Shoot fireball partway through surface duration
			if not has_shot and state_timer < SURFACE_DURATION * 0.6:
				_shoot_fireball()
				has_shot = true
			if state_timer <= 0:
				_enter_submerging()
		State.SUBMERGING:
			if state_timer <= 0:
				_enter_submerged()


func _enter_submerged() -> void:
	state = State.SUBMERGED
	state_timer = randf_range(SUBMERGED_TIME_MIN, SUBMERGED_TIME_MAX)
	sprite.visible = false
	_set_collision_enabled(false)


func _enter_emerging() -> void:
	state = State.EMERGING
	state_timer = EMERGE_DURATION
	sprite.visible = true
	_set_collision_enabled(false)  # Still invulnerable while emerging
	sprite.play("emerge")


func _enter_surface() -> void:
	state = State.SURFACE
	state_timer = SURFACE_DURATION
	_set_collision_enabled(true)
	has_shot = false
	_face_player()


func _enter_submerging() -> void:
	state = State.SUBMERGING
	state_timer = SUBMERGE_DURATION
	_set_collision_enabled(false)  # Invulnerable while submerging
	sprite.play("submerge")


func _set_collision_enabled(enabled: bool) -> void:
	body_collision.set_deferred("disabled", not enabled)
	hitbox_shape.set_deferred("disabled", not enabled)
	contact_shape.set_deferred("disabled", not enabled)


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().get_node_or_null("../Player")
	if player:
		var diff: Vector2 = player.global_position - global_position
		if diff.y >= 0:
			sprite.play("face_down")
		else:
			sprite.play("face_up")
	else:
		sprite.play("face_down")


func _shoot_fireball() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().get_node_or_null("../Player")
	if not player:
		return

	var fireball = preload("res://scenes/enemies/zora_fireball.tscn").instantiate()
	fireball.direction = (player.global_position - global_position).normalized()
	fireball.global_position = global_position
	get_parent().add_child(fireball)


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
		if tilemap and _is_water_tile(tilemap, target_pos):
			global_position = target_pos
			return

	# Fallback: stay at current position if no water tile found


func _get_tilemap() -> TileMapLayer:
	# enemies_container is child of screen_manager, tilemap is sibling
	var screen_manager = get_parent().get_parent()
	if screen_manager:
		return screen_manager.get_node_or_null("TileMapLayer") as TileMapLayer
	return null


func _is_water_tile(tilemap: TileMapLayer, pos: Vector2) -> bool:
	var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(pos))
	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
	# Atlas coords are (col, row) in the tileset
	# WATER_TILES uses (row, col) format, so compare as (row, col)
	var tile_row_col := Vector2i(atlas_coords.y, atlas_coords.x)
	return tile_row_col in WATER_TILES


func take_damage(amount: int) -> void:
	# Only vulnerable during SURFACE state
	if is_dead or state != State.SURFACE:
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
