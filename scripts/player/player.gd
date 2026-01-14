extends CharacterBody2D
## Player character with 4-directional movement and sword attack.

# Health signals for HUD integration
signal health_changed(current: int, maximum: int)
signal player_died

# Debug settings
const DEBUG_SLOW_MOTION := false  # Set to false to disable slow motion
const DEBUG_TIME_SCALE := 0.1    # Game speed when slow motion is enabled

# Movement speed matching NES Zelda feel
const MOVE_SPEED := 90.0  # pixels per second

# Attack cooldown duration (NES Zelda feel)
const ATTACK_COOLDOWN_DURATION := 0.15  # seconds

# Health system constants
const INVINCIBILITY_DURATION := 1.0  # seconds of invincibility after hit
const KNOCKBACK_SPEED := 150.0  # pixels/sec
const KNOCKBACK_DECELERATION := 600.0  # pixels/sec²
const PALETTE_CYCLE_SPEED := 10.0  # palette frames per second

# Death animation constants
const DEATH_SPIN_DURATION := 2.0  # seconds
const DEATH_SPIN_SPEED := 12.0  # frames per second (rapid spin)

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
var attack_cooldown := 0.0  # Time remaining before next attack allowed
var subpixel_position := Vector2.ZERO  # Tracks true position for physics

# Health state
var health := 3
var max_health := 3
var invincibility_timer := 0.0
var knockback_velocity := Vector2.ZERO
var is_dead := false
var palette_frame := 0  # 0-3 for shader (0 = normal)

# Death animation state
var death_spin_timer := 0.0
var death_frame_timer := 0.0
var death_frame_index := 0  # 0-3 for down/right/up/left


func _ready() -> void:
	add_to_group("player")

	if DEBUG_SLOW_MOTION:
		Engine.time_scale = DEBUG_TIME_SCALE

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	update_animation()


func _physics_process(delta: float) -> void:
	# Restore true subpixel position for physics calculations
	if subpixel_position != Vector2.ZERO:
		global_position = subpixel_position

	# Handle death state (spin animation)
	if is_dead:
		_process_death_animation(delta)
		return

	# Handle invincibility and palette cycling
	if invincibility_timer > 0:
		invincibility_timer -= delta
		# Cycle through palette frames 1-3 (skip 0 which is normal)
		palette_frame = 1 + int(invincibility_timer * PALETTE_CYCLE_SPEED) % 3
		sprite.material.set_shader_parameter("palette_frame", palette_frame)

		if invincibility_timer <= 0:
			palette_frame = 0
			sprite.material.set_shader_parameter("palette_frame", 0)

	# Apply knockback velocity
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECELERATION * delta)
		move_and_slide()
		_snap_to_pixel()
		# Don't process normal input while being knocked back
		if knockback_velocity.length() > 10.0:
			return

	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Lock input during screen transitions
	if screen_manager.is_transitioning:
		velocity = Vector2.ZERO
		is_moving = false
		update_animation()
		_snap_to_pixel()
		return

	# Handle attack input (requires cooldown to be finished)
	if Input.is_action_just_pressed("attack") and not is_attacking and attack_cooldown <= 0:
		start_attack()

	# Don't allow movement during attack
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_snap_to_pixel()
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

	# Check for cave entrance (before screen transition check)
	if screen_manager.check_cave_entrance(global_position):
		return  # Entering cave, skip other checks

	# Check for screen edge crossing
	check_screen_transition(old_screen)

	_snap_to_pixel()


func _snap_to_pixel() -> void:
	# Store true position for physics, snap for rendering (NES-style)
	subpixel_position = global_position
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
	## Start sword attack (requires sword to be equipped)
	if not GameManager.has_sword():
		return
	is_attacking = true
	update_animation()


func receive_sword() -> void:
	## Called when player collects a sword pickup
	# Visual/audio feedback could be added here
	pass


func _on_animation_finished() -> void:
	if is_attacking:
		end_attack()


func end_attack() -> void:
	is_attacking = false
	attack_cooldown = ATTACK_COOLDOWN_DURATION
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

	# Positions calculated for centered=false (top-left origin)
	# Formula: new_pos = old_centered_pos - (width/2, height/2)

	match facing:
		Direction.DOWN:
			sword_anim = "sword_down"
			sword_sprite.flip_h = false
			# Sprite sizes: 8x11, 8x7, 8x3
			var down_sword_x := [-3, -3, -3]
			var down_sword_y := [8, 8, 7]
			sword.position = Vector2(down_sword_x[sword_frame], down_sword_y[sword_frame])
		Direction.UP:
			sword_anim = "sword_up"
			sword_sprite.flip_h = false
			# Sprite sizes: 8x12, 8x12, 8x3
			var up_sword_x := [-5, -5, -5]
			var up_sword_y := [-20, -20, -11]
			sword.position = Vector2(up_sword_x[sword_frame], up_sword_y[sword_frame])
		Direction.LEFT:
			sword_anim = "sword_side"
			sword_sprite.flip_h = true
			# Sprite sizes: 11x16, 7x16, 3x16 (flip_h extends left from position)
			var left_sword_x := [-19, -15, -11]  # -8 - width for each frame
			sword.position = Vector2(left_sword_x[sword_frame], -7)
		Direction.RIGHT:
			sword_anim = "sword_side"
			sword_sprite.flip_h = false
			# Sprite sizes: 11x16, 7x16, 3x16
			var right_sword_x := [8, 8, 8]
			sword.position = Vector2(right_sword_x[sword_frame], -7)

	if sword_sprite.sprite_frames and sword_sprite.sprite_frames.has_animation(sword_anim):
		sword_sprite.animation = sword_anim
		sword_sprite.frame = sword_frame


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


func _on_sword_area_entered(area: Area2D) -> void:
	## Handle sword collision with enemies
	if area.is_in_group("enemies"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(1)


# =============================================================================
# Health System
# =============================================================================

func heal(amount: int) -> void:
	## Restore health (called by heart pickups)
	if is_dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func take_damage(amount: int, from_position: Vector2) -> void:
	## Apply damage to player, trigger invincibility and knockback
	if is_dead or invincibility_timer > 0:
		return

	health -= amount
	health = max(health, 0)
	health_changed.emit(health, max_health)

	# Start invincibility
	invincibility_timer = INVINCIBILITY_DURATION

	# Calculate knockback direction (away from damage source)
	var knockback_dir := (global_position - from_position).normalized()
	knockback_velocity = knockback_dir * KNOCKBACK_SPEED

	if health <= 0:
		die()


func die() -> void:
	## Trigger death state and start spin animation
	is_dead = true
	is_attacking = false
	is_moving = false
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO

	# Start death spin animation
	death_spin_timer = DEATH_SPIN_DURATION
	death_frame_timer = 0.0
	death_frame_index = 0
	_update_death_frame()


func _process_death_animation(delta: float) -> void:
	## Handle death spin animation each frame
	if death_spin_timer > 0:
		death_spin_timer -= delta
		death_frame_timer += delta

		# Continue palette cycling during death
		palette_frame = 1 + int(death_spin_timer * PALETTE_CYCLE_SPEED) % 3
		sprite.material.set_shader_parameter("palette_frame", palette_frame)

		# Cycle through death frames at DEATH_SPIN_SPEED
		if death_frame_timer >= 1.0 / DEATH_SPIN_SPEED:
			death_frame_timer = 0.0
			death_frame_index = (death_frame_index + 1) % 4
			_update_death_frame()

		if death_spin_timer <= 0:
			player_died.emit()  # Signal after animation completes

	velocity = Vector2.ZERO
	move_and_slide()
	_snap_to_pixel()


func _update_death_frame() -> void:
	## Update sprite for death spin: down → right → up → left (flipped right)
	match death_frame_index:
		0:  # Down
			sprite.animation = "walk_down"
			sprite.frame = 0
			sprite.flip_h = false
		1:  # Right
			sprite.animation = "walk_side"
			sprite.frame = 0
			sprite.flip_h = false
		2:  # Up
			sprite.animation = "walk_up"
			sprite.frame = 0
			sprite.flip_h = false
		3:  # Left (right flipped)
			sprite.animation = "walk_side"
			sprite.frame = 0
			sprite.flip_h = true
