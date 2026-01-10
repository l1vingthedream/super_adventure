extends Pickup
class_name ArrowPickup
## Arrow pickup - adds 1 arrow to player inventory.


func _apply_pickup(_player: Node2D) -> void:
	GameManager.add_arrows(1)
