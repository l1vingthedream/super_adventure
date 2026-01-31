extends CharacterBody2D
## Peahat - flying enemy that spins while moving randomly. Invulnerable
## while flying, only vulnerable during brief stops.

const MOVE_SPEED := 50.0
const HEALTH := 2
const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0
const FLY_TIME_MIN := 2.0
const FLY_TIME_MAX := 4.0
const STOP_TIME_MIN := 0.8
const STOP_TIME_MAX := 1.5
const TRANSITION_TIME := 0.3

enum State { FLYING, STOPPING, STOPPED, STARTING }

var health := HEALTH
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0
var state := State.FLYING
var state_timer := 0.0
var move_direction := Vector2.ZERO
var current_speed := MOVE_SPEED

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage


func _ready() -> void:
	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)
	_pick_random_direction()
	_enter_flying()
	state_timer = randf_range(1.0, FLY_TIME_MAX)


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
		State.FLYING:
			velocity = move_direction * current_speed
			move_and_slide()
			if get_slide_collision_count() > 0:
				_pick_random_direction()
			if state_timer <= 0:
				_enter_stopping()
		State.STOPPING:
			# Decelerate
			var t := state_timer / TRANSITION_TIME
			current_speed = MOVE_SPEED * t
			velocity = move_direction * current_speed
			move_and_slide()
			sprite.speed_scale = 0.5 + 1.5 * t
			if state_timer <= 0:
				_enter_stopped()
		State.STOPPED:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_enter_starting()
		State.STARTING:
			# Accelerate
			var t := 1.0 - (state_timer / TRANSITION_TIME)
			current_speed = MOVE_SPEED * t
			velocity = move_direction * current_speed
			move_and_slide()
			sprite.speed_scale = 0.5 + 1.5 * t
			if state_timer <= 0:
				_enter_flying()


func _enter_flying() -> void:
	state = State.FLYING
	state_timer = randf_range(FLY_TIME_MIN, FLY_TIME_MAX)
	current_speed = MOVE_SPEED
	sprite.speed_scale = 2.0
	sprite.play("spin")
	_pick_random_direction()


func _enter_stopping() -> void:
	state = State.STOPPING
	state_timer = TRANSITION_TIME


func _enter_stopped() -> void:
	state = State.STOPPED
	state_timer = randf_range(STOP_TIME_MIN, STOP_TIME_MAX)
	current_speed = 0.0
	sprite.speed_scale = 0.0


func _enter_starting() -> void:
	state = State.STARTING
	state_timer = TRANSITION_TIME
	_pick_random_direction()
	sprite.play("spin")


func _pick_random_direction() -> void:
	var angle := randf() * TAU
	move_direction = Vector2(cos(angle), sin(angle)).normalized()


func take_damage(amount: int) -> void:
	if is_dead or state != State.STOPPED:
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
