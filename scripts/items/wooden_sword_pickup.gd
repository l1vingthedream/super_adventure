extends Area2D
## Wooden sword pickup that grants the player attack ability.

signal collected

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Connect to body entered signal
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	## Handle player collision with sword pickup
	if not body.is_in_group("player"):
		return

	# Grant sword to player
	GameManager.acquire_sword(GameManager.Sword.WOODEN)

	# Call player's receive_sword method for any visual/audio feedback
	if body.has_method("receive_sword"):
		body.receive_sword()

	collected.emit()

	# Remove pickup from scene
	queue_free()
