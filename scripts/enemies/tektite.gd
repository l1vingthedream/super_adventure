class_name Tektite
extends CharacterBody2D
## Tektite enemy - spider-like creature that hops randomly.
## Red variant moves frequently (short pauses), Blue variant is more sluggish (longer pauses).

enum TektiteColor { RED, BLUE }
enum State { IDLE, JUMPING }

# Configuration
@export var color: TektiteColor = TektiteColor.RED

# Stats based on color (set in _ready)
var health: int
var pause_time_min: float
var pause_time_max: float

const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0
const JUMP_SPEED := 80.0  # Horizontal movement speed during jump
const JUMP_HEIGHT := 40.0  # Peak height of jump arc
const JUMP_DURATION := 0.4  # Time for full jump arc

# State
var state := State.IDLE
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0
var pause_timer := 0.0
var jump_timer := 0.0
var jump_direction := Vector2.ZERO
var start_y := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage


func _ready() -> void:
	# Set stats based on color variant
	if color == TektiteColor.RED:
		health = 1
		pause_time_min = 0.3
		pause_time_max = 0.8
	else:  # BLUE
		health = 2
		pause_time_min = 1.0
		pause_time_max = 2.0

	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)

	# Start with a random pause
	_start_idle()

	# Update sprite for color
	_update_animation()


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

	match state:
		State.IDLE:
			_process_idle(delta)
		State.JUMPING:
			_process_jumping(delta)


func _process_idle(delta: float) -> void:
	pause_timer -= delta
	if pause_timer <= 0:
		_start_jump()


func _process_jumping(delta: float) -> void:
	jump_timer += delta

	# Calculate jump progress (0 to 1)
	var t := jump_timer / JUMP_DURATION

	if t >= 1.0:
		# Jump complete - land
		global_position.y = start_y
		velocity = Vector2.ZERO
		move_and_slide()
		_start_idle()
		return

	# Move horizontally
	velocity.x = jump_direction.x * JUMP_SPEED
	velocity.y = jump_direction.y * JUMP_SPEED

	# Apply parabolic arc (modify y position)
	# Arc formula: height = 4 * peak_height * t * (1 - t)
	var arc_offset := -4.0 * JUMP_HEIGHT * t * (1.0 - t)

	move_and_slide()

	# Apply visual arc offset to sprite (so collision stays grounded)
	sprite.position.y = arc_offset

	# Check for wall collision - if hit wall, reverse horizontal direction
	if get_slide_collision_count() > 0:
		jump_direction.x = -jump_direction.x


func _start_idle() -> void:
	state = State.IDLE
	pause_timer = randf_range(pause_time_min, pause_time_max)
	sprite.position.y = 0  # Reset sprite position
	_update_animation()


func _start_jump() -> void:
	state = State.JUMPING
	jump_timer = 0.0
	start_y = global_position.y

	# Pick random jump direction
	var angle := randf() * TAU  # Random angle 0 to 2*PI
	jump_direction = Vector2(cos(angle), sin(angle)).normalized()

	# Bias slightly toward horizontal movement
	jump_direction.y *= 0.5
	jump_direction = jump_direction.normalized()

	_update_animation()


func _on_contact_damage_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	damage_flash_timer = DAMAGE_FLASH_DURATION
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


func _update_animation() -> void:
	# Tektite uses color-specific animations
	var prefix := "red_" if color == TektiteColor.RED else "blue_"
	if state == State.JUMPING:
		sprite.play(prefix + "jump")
	else:
		sprite.play(prefix + "idle")
