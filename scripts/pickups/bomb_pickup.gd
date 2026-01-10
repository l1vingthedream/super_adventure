extends Pickup
class_name BombPickup
## Bomb pickup - adds 1 bomb to player inventory.


func _apply_pickup(_player: Node2D) -> void:
	GameManager.add_bombs(1)
