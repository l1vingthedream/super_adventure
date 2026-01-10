extends Area2D
class_name Pickup
## Base class for all collectible pickups.

const DESPAWN_TIME := 10.0  # Seconds before auto-despawn (like original Zelda)
const BLINK_START := 3.0    # Seconds before despawn to start blinking

var time_alive: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var despawn_timer: Timer = $DespawnTimer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	despawn_timer.timeout.connect(_on_despawn)
	despawn_timer.start(DESPAWN_TIME)
	# Set collision to detect player (layer 2)
	collision_layer = 0
	collision_mask = 2  # Player layer


func _process(delta: float) -> void:
	time_alive += delta
	# Blink warning before despawn (last 3 seconds)
	if despawn_timer.time_left < BLINK_START:
		sprite.visible = int(time_alive * 10) % 2 == 0


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_apply_pickup(body)
		queue_free()


func _apply_pickup(_player: Node2D) -> void:
	## Override in subclasses to apply the pickup effect
	pass


func _on_despawn() -> void:
	queue_free()
