extends Area2D
## Falling rock hazard — spawns at top of screen, tumbles down in an erratic
## diagonal bouncing pattern (like NES Zelda Death Mountain boulders).
## Unkillable (no health, no hitbox group). Damages player on contact.

const FALL_SPEED := 100.0
const HORIZONTAL_SPEED := 60.0
const SCREEN_HEIGHT_PX := 176
const SCREEN_WIDTH_PX := 256
const BOUNCE_MIN := 0.3  # Min time before reversing horizontal direction
const BOUNCE_MAX := 0.8  # Max time before reversing horizontal direction

var spawn_screen_top := 0.0   # Set by spawner to know when to despawn
var spawn_screen_left := 0.0  # Set by spawner for horizontal bounds
var h_direction := 1.0        # 1.0 = right, -1.0 = left
var bounce_timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Randomize initial horizontal direction
	h_direction = 1.0 if randf() > 0.5 else -1.0
	bounce_timer = randf_range(BOUNCE_MIN, BOUNCE_MAX)


func _physics_process(delta: float) -> void:
	position.y += FALL_SPEED * delta
	position.x += HORIZONTAL_SPEED * h_direction * delta

	# Bounce timer — periodically reverse horizontal direction
	bounce_timer -= delta
	if bounce_timer <= 0:
		h_direction = -h_direction
		bounce_timer = randf_range(BOUNCE_MIN, BOUNCE_MAX)

	# Bounce off screen edges
	if global_position.x < spawn_screen_left + 8:
		global_position.x = spawn_screen_left + 8
		h_direction = 1.0
		bounce_timer = randf_range(BOUNCE_MIN, BOUNCE_MAX)
	elif global_position.x > spawn_screen_left + SCREEN_WIDTH_PX - 8:
		global_position.x = spawn_screen_left + SCREEN_WIDTH_PX - 8
		h_direction = -1.0
		bounce_timer = randf_range(BOUNCE_MIN, BOUNCE_MAX)

	# Despawn when below screen bottom
	if global_position.y > spawn_screen_top + SCREEN_HEIGHT_PX + 16:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
