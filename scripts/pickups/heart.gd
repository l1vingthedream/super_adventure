extends Pickup
class_name HeartPickup
## Heart pickup - restores 1 health to player.


func _apply_pickup(player: Node2D) -> void:
	if player.has_method("heal"):
		player.heal(1)
