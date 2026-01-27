extends Area2D
## Octorok rock projectile - travels in a direction, damages player on hit.

const SPEED := 100.0
const LIFETIME := 3.0  # Despawn after 3 seconds
const SCREEN_WIDTH_PX := 256
const SCREEN_HEIGHT_PX := 176

var direction := Vector2.DOWN
var lifetime_timer := 0.0
var origin_screen_bounds: Rect2

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Calculate origin screen bounds - projectile despawns if it leaves this screen
	var screen_x := int(global_position.x / SCREEN_WIDTH_PX)
	var screen_y := int(global_position.y / SCREEN_HEIGHT_PX)
	origin_screen_bounds = Rect2(
		screen_x * SCREEN_WIDTH_PX,
		screen_y * SCREEN_HEIGHT_PX,
		SCREEN_WIDTH_PX,
		SCREEN_HEIGHT_PX
	)

	# Rotate sprite based on direction
	# The sprite faces right by default, so we rotate based on direction angle
	sprite.rotation = direction.angle()

	# Connect to detect collisions
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

	# Despawn if projectile leaves origin screen
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
	# Check for tile collision (CharacterBody2D used for tilemap collision)
	# The projectile will just despawn after lifetime if it doesn't hit anything
