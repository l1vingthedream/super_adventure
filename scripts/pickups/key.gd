extends Pickup
class_name KeyPickup
## Key pickup - adds 1 key to player inventory.
## Note: Keys are excluded from general enemy drops.
## They only drop from dungeon-specific enemies or forced drops.


func _apply_pickup(_player: Node2D) -> void:
	GameManager.add_keys(1)
