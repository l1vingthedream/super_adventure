extends Area2D
## Octorok rock projectile - travels in a direction, damages player on hit.

const SPEED := 100.0
const LIFETIME := 3.0  # Despawn after 3 seconds

var direction := Vector2.DOWN
var lifetime_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Rotate sprite based on direction
	# The sprite faces right by default, so we rotate based on direction angle
	sprite.rotation = direction.angle()

	# Connect to detect collisions
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

	lifetime_timer += delta
	if lifetime_timer >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		queue_free()
	# Check for tile collision (CharacterBody2D used for tilemap collision)
	# The projectile will just despawn after lifetime if it doesn't hit anything
