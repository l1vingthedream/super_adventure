extends CharacterBody2D
class_name Lynel
## Lynel - walks in cardinal directions and shoots sword beams.
## Red (4 HP, slower) and Blue (6 HP, faster) variants.

const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0

enum LynelColor { RED, BLUE }
enum Direction { DOWN, UP, LEFT, RIGHT }

@export var color: LynelColor = LynelColor.RED

var health := 4
var move_speed := 40.0
var shoot_cooldown := 2.5
var direction_change_time := 1.5
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

	# Configure stats by color
	if color == LynelColor.BLUE:
		health = 6
		move_speed = 50.0
		shoot_cooldown = 2.0
		direction_change_time = 1.0

	_pick_random_direction()
	shoot_timer = randf() * shoot_cooldown
	move_timer = randf() * direction_change_time


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

	# Movement timer
	move_timer += delta
	if move_timer >= direction_change_time:
		move_timer = 0.0
		_pick_random_direction()

	# Move
	velocity = _get_direction_vector() * move_speed
	move_and_slide()

	# Bounce off walls
	if get_slide_collision_count() > 0:
		_pick_random_direction()

	# Shoot timer
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		_shoot_sword_beam()

	_update_animation()


func _pick_random_direction() -> void:
	facing = randi() % 4 as Direction


func _get_direction_vector() -> Vector2:
	match facing:
		Direction.DOWN: return Vector2.DOWN
		Direction.UP: return Vector2.UP
		Direction.LEFT: return Vector2.LEFT
		Direction.RIGHT: return Vector2.RIGHT
	return Vector2.ZERO


func _shoot_sword_beam() -> void:
	var beam = preload("res://scenes/enemies/lynel_sword_beam.tscn").instantiate()
	beam.direction = _get_direction_vector()
	beam.global_position = global_position
	get_parent().add_child(beam)


func take_damage(amount: int) -> void:
	if is_dead:
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


func _update_animation() -> void:
	var prefix := "red" if color == LynelColor.RED else "blue"
	match facing:
		Direction.DOWN:
			sprite.play(prefix + "_walk_down")
			sprite.flip_h = false
		Direction.UP:
			sprite.play(prefix + "_walk_up")
			sprite.flip_h = false
		Direction.LEFT:
			sprite.play(prefix + "_walk_side")
			sprite.flip_h = false
		Direction.RIGHT:
			sprite.play(prefix + "_walk_side")
			sprite.flip_h = true
