extends Area2D
## Moblin spear projectile - travels in a cardinal direction, damages player on hit.
## Uses directional sprites instead of rotation.

const SPEED := 100.0
const LIFETIME := 3.0
const SCREEN_WIDTH_PX := 256
const SCREEN_HEIGHT_PX := 176

var direction := Vector2.DOWN
var lifetime_timer := 0.0
var origin_screen_bounds: Rect2

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	var screen_x := int(global_position.x / SCREEN_WIDTH_PX)
	var screen_y := int(global_position.y / SCREEN_HEIGHT_PX)
	origin_screen_bounds = Rect2(
		screen_x * SCREEN_WIDTH_PX,
		screen_y * SCREEN_HEIGHT_PX,
		SCREEN_WIDTH_PX,
		SCREEN_HEIGHT_PX
	)

	# Set sprite direction using flip instead of rotation
	if direction == Vector2.UP:
		sprite.flip_v = false
		sprite.flip_h = false
		sprite.region_rect = Rect2(150, 11, 8, 16)
	elif direction == Vector2.DOWN:
		sprite.flip_v = true
		sprite.flip_h = false
		sprite.region_rect = Rect2(150, 11, 8, 16)
	elif direction == Vector2.RIGHT:
		sprite.flip_h = false
		sprite.region_rect = Rect2(159, 11, 16, 16)
	elif direction == Vector2.LEFT:
		sprite.flip_h = true
		sprite.region_rect = Rect2(159, 11, 16, 16)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

	if not origin_screen_bounds.has_point(global_position):
		queue_free()
		return

	lifetime_timer += delta
	if lifetime_timer >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		queue_free()
