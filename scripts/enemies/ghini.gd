extends CharacterBody2D
## Ghini - gliding ghost enemy. Moves smoothly in random directions,
## changes angle every ~2s, bounces off walls. High HP (9), slow speed.

const MOVE_SPEED := 35.0
const HEALTH := 9
const DIRECTION_CHANGE_TIME := 2.0
const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0

var health := HEALTH
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0
var move_timer := 0.0
var move_direction := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage


func _ready() -> void:
	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)
	_pick_random_direction()
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

	# Direction change timer
	move_timer += delta
	if move_timer >= DIRECTION_CHANGE_TIME:
		move_timer = 0.0
		_pick_random_direction()

	# Move
	velocity = move_direction * MOVE_SPEED
	move_and_slide()

	# Bounce off walls
	if get_slide_collision_count() > 0:
		_pick_random_direction()

	_update_animation()


func _pick_random_direction() -> void:
	var angle := randf() * TAU
	move_direction = Vector2(cos(angle), sin(angle)).normalized()


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
	if move_direction.y < 0:
		sprite.play("walk_up")
	else:
		sprite.play("walk_down")
	sprite.flip_h = move_direction.x < 0
