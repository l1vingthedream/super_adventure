extends CharacterBody2D
## Octorok enemy - walks randomly, shoots projectiles, deals contact damage.

const MOVE_SPEED := 40.0  # Slower than player (90)
const HEALTH := 2  # Dies in 2 sword hits
const SHOOT_COOLDOWN := 2.0  # Seconds between shots
const DIRECTION_CHANGE_TIME := 1.5  # Seconds before changing direction
const DAMAGE_FLASH_DURATION := 0.3  # Seconds of palette cycling on hit
const DAMAGE_FLASH_SPEED := 15.0  # Palette frames per second

enum Direction { DOWN, UP, LEFT, RIGHT }

var health := HEALTH
var facing := Direction.DOWN
var move_timer := 0.0
var shoot_timer := 0.0
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage


func _ready() -> void:
	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)
	_pick_random_direction()
	# Randomize initial timers so enemies don't all shoot at once
	shoot_timer = randf() * SHOOT_COOLDOWN
	move_timer = randf() * DIRECTION_CHANGE_TIME


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

	# Movement timer - change direction periodically
	move_timer += delta
	if move_timer >= DIRECTION_CHANGE_TIME:
		move_timer = 0.0
		_pick_random_direction()

	# Move in facing direction
	velocity = _get_direction_vector() * MOVE_SPEED
	move_and_slide()

	# Bounce off walls
	if get_slide_collision_count() > 0:
		_pick_random_direction()

	# Shoot timer
	shoot_timer += delta
	if shoot_timer >= SHOOT_COOLDOWN:
		shoot_timer = 0.0
		_shoot_projectile()

	_update_animation()


func _on_contact_damage_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	damage_flash_timer = DAMAGE_FLASH_DURATION  # Start damage flash
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	# Spawn universal death effect at our position
	var death_effect = preload("res://scenes/enemies/enemy_death.tscn").instantiate()
	death_effect.global_position = global_position
	get_parent().add_child(death_effect)

	# Spawn random drop
	DropSystem.spawn_drop(global_position, get_parent())

	queue_free()


func _pick_random_direction() -> void:
	facing = randi() % 4 as Direction


func _get_direction_vector() -> Vector2:
	match facing:
		Direction.DOWN: return Vector2.DOWN
		Direction.UP: return Vector2.UP
		Direction.LEFT: return Vector2.LEFT
		Direction.RIGHT: return Vector2.RIGHT
	return Vector2.ZERO


func _shoot_projectile() -> void:
	var projectile = preload("res://scenes/enemies/octorok_projectile.tscn").instantiate()
	projectile.direction = _get_direction_vector()
	projectile.global_position = global_position
	get_parent().add_child(projectile)


func _update_animation() -> void:
	match facing:
		Direction.DOWN:
			sprite.play("walk_down")
			sprite.flip_h = false
			sprite.flip_v = false
		Direction.UP:
			sprite.play("walk_down")
			sprite.flip_h = false
			sprite.flip_v = true
		Direction.LEFT:
			sprite.play("walk_side")
			sprite.flip_h = false
		Direction.RIGHT:
			sprite.play("walk_side")
			sprite.flip_h = true
