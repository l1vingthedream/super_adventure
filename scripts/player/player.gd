extends CharacterBody2D
## Player character with 4-directional movement in the style of original Zelda.

# Movement speed matching NES Zelda feel
const MOVE_SPEED := 90.0  # pixels per second

# Current facing direction for animations
enum Direction { DOWN, UP, LEFT, RIGHT }
var facing := Direction.DOWN

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# State
var is_moving := false


func _ready() -> void:
	update_animation()


func _physics_process(_delta: float) -> void:
	var input_dir := get_input_direction()
	velocity = input_dir * MOVE_SPEED

	var was_moving := is_moving
	is_moving = input_dir != Vector2.ZERO

	if is_moving:
		update_facing(input_dir)

	if is_moving != was_moving or is_moving:
		update_animation()

	move_and_slide()

	# Snap sprite to whole pixels to prevent subpixel rendering artifacts
	sprite.position = sprite.position.round()
	global_position = global_position.round()


func get_input_direction() -> Vector2:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1

	return dir.normalized()


func update_facing(dir: Vector2) -> void:
	# Prioritize horizontal movement like original Zelda
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			facing = Direction.RIGHT
		else:
			facing = Direction.LEFT
	else:
		if dir.y > 0:
			facing = Direction.DOWN
		else:
			facing = Direction.UP


func update_animation() -> void:
	var anim_name: String

	if is_moving:
		match facing:
			Direction.DOWN:
				anim_name = "walk_down"
				sprite.flip_h = false
			Direction.UP:
				anim_name = "walk_up"
				sprite.flip_h = false
			Direction.LEFT:
				anim_name = "walk_side"
				sprite.flip_h = true
			Direction.RIGHT:
				anim_name = "walk_side"
				sprite.flip_h = false
	else:
		match facing:
			Direction.DOWN:
				anim_name = "idle_down"
				sprite.flip_h = false
			Direction.UP:
				anim_name = "idle_up"
				sprite.flip_h = false
			Direction.LEFT:
				anim_name = "idle_side"
				sprite.flip_h = true
			Direction.RIGHT:
				anim_name = "idle_side"
				sprite.flip_h = false

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
