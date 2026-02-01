extends Area2D
## Heart container pickup — increases max hearts by 1 and heals to full.
## Part of the pick-one-of-two secret cave items.


func _ready() -> void:
	add_to_group("secret_cave_choices")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	# Increase max health and heal to full
	body.max_health += 1
	body.health = body.max_health
	body.health_changed.emit(body.health, body.max_health)

	# Remove all pick-one choices
	for node in get_tree().get_nodes_in_group("secret_cave_choices"):
		node.queue_free()
