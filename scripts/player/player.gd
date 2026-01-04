extends CharacterBody2D
## Player character with 4-directional movement and sword attack.

# Movement speed matching NES Zelda feel
const MOVE_SPEED := 90.0  # pixels per second

# Current facing direction for animations
enum Direction { DOWN, UP, LEFT, RIGHT }
var facing := Direction.DOWN

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sword: Area2D = $Sword
@onready var sword_sprite: AnimatedSprite2D = $Sword/SwordSprite
@onready var sword_hitbox: CollisionShape2D = $Sword/SwordHitbox
@onready var screen_manager: Node2D = get_parent()

# State
var is_moving := false
var is_attacking := false


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	update_animation()


func _physics_process(_delta: float) -> void:
	# Lock input during screen transitions
	if screen_manager.is_transitioning:
		velocity = Vector2.ZERO
		is_moving = false
		update_animation()
		return

	# Handle attack input
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()

	# Don't allow movement during attack
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir := get_input_direction()
	velocity = input_dir * MOVE_SPEED

	var was_moving := is_moving
	is_moving = input_dir != Vector2.ZERO

	if is_moving:
		update_facing(input_dir)

	if is_moving != was_moving or is_moving:
		update_animation()

	# Store position before movement for edge detection
	var old_screen: Vector2i = screen_manager.get_screen_from_position(global_position)

	move_and_slide()

	# Check for screen edge crossing
	check_screen_transition(old_screen)

	# Snap sprite visually using offset to prevent subpixel rendering artifacts
	var subpixel := global_position - global_position.floor()
	sprite.offset = -subpixel


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

	if is_attacking:
		match facing:
			Direction.DOWN:
				anim_name = "attack_down"
				sprite.flip_h = false
			Direction.UP:
				anim_name = "attack_up"
				sprite.flip_h = false
			Direction.LEFT:
				anim_name = "attack_side"
				sprite.flip_h = true
			Direction.RIGHT:
				anim_name = "attack_side"
				sprite.flip_h = false
	elif is_moving:
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


func start_attack() -> void:
	is_attacking = true
	update_animation()


func _on_animation_finished() -> void:
	if is_attacking:
		end_attack()


func end_attack() -> void:
	is_attacking = false
	sword.visible = false
	sword_hitbox.disabled = true
	update_animation()


func _on_frame_changed() -> void:
	if not is_attacking:
		return

	var frame := sprite.frame

	# Frame 0: sword hidden, frames 1-3: sword visible
	if frame == 0:
		sword.visible = false
		sword_hitbox.disabled = true
	else:
		sword.visible = true
		sword_hitbox.disabled = false
		update_sword_position(frame - 1)  # sword frames are 0-2, player frames 1-3


func update_sword_position(sword_frame: int) -> void:
	var sword_anim: String

	# Sword Y positions per frame (calculated from sprite heights)
	var down_sword_y := [14, 12, 10]  # Top aligned with player bottom (y=8)
	var up_sword_y := [-14, -14, -10]  # Bottom aligned with player top (y=-8)

	match facing:
		Direction.DOWN:
			sword_anim = "sword_down"
			sword_sprite.flip_h = false
			# Position below player, x=2, y varies per frame to keep top at player feet
			sword.position = Vector2(2, down_sword_y[sword_frame])
		Direction.UP:
			sword_anim = "sword_up"
			sword_sprite.flip_h = false
			# Position above player, x=0, y varies per frame to keep bottom at player head
			sword.position = Vector2(0, up_sword_y[sword_frame])
		Direction.LEFT:
			sword_anim = "sword_side"
			sword_sprite.flip_h = true
			# Position left of player
			sword.position = Vector2(-14, 1)
		Direction.RIGHT:
			sword_anim = "sword_side"
			sword_sprite.flip_h = false
			# Position right of player
			sword.position = Vector2(14, 1)

	if sword_sprite.sprite_frames and sword_sprite.sprite_frames.has_animation(sword_anim):
		sword_sprite.animation = sword_anim
		sword_sprite.frame = sword_frame

	# Apply subpixel snapping to sword sprite (same as player sprite)
	var sword_subpixel := sword.global_position - sword.global_position.floor()
	sword_sprite.offset = -sword_subpixel


func check_screen_transition(old_screen: Vector2i) -> void:
	## Check if player crossed a screen boundary and trigger transition
	var new_screen: Vector2i = screen_manager.get_screen_from_position(global_position)

	if new_screen == old_screen:
		return

	# Calculate transition direction
	var direction: Vector2i = new_screen - old_screen

	# Check if target screen is valid (within map bounds)
	if not screen_manager.can_transition_to(new_screen):
		# Clamp player to current screen bounds
		clamp_to_screen(old_screen)
		return

	# Start the transition
	screen_manager.start_player_transition(new_screen, direction, self)


func clamp_to_screen(screen: Vector2i) -> void:
	## Clamp player position to stay within the given screen bounds
	var screen_left: float = screen.x * screen_manager.SCREEN_WIDTH_PX
	var screen_right: float = (screen.x + 1) * screen_manager.SCREEN_WIDTH_PX
	var screen_top: float = screen.y * screen_manager.SCREEN_HEIGHT_PX
	var screen_bottom: float = (screen.y + 1) * screen_manager.SCREEN_HEIGHT_PX

	# Account for player collision size (half of 12px = 6px)
	var margin := 6.0

	global_position.x = clampf(global_position.x, screen_left + margin, screen_right - margin)
	global_position.y = clampf(global_position.y, screen_top + margin, screen_bottom - margin)
