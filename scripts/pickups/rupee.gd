extends Pickup
class_name RupeePickup
## Rupee pickup - adds rupees to player inventory.

enum RupeeType { YELLOW = 1, BLUE = 5 }

@export var rupee_type: RupeeType = RupeeType.YELLOW

# Sprite regions for each rupee type
const RUPEE_REGIONS := {
	RupeeType.YELLOW: Rect2(72, 0, 8, 16),
	RupeeType.BLUE: Rect2(72, 16, 8, 16),
}


func _ready() -> void:
	super._ready()
	_update_sprite()


func _update_sprite() -> void:
	if sprite and rupee_type in RUPEE_REGIONS:
		sprite.region_rect = RUPEE_REGIONS[rupee_type]


func set_rupee_type(type: RupeeType) -> void:
	rupee_type = type
	_update_sprite()


func _apply_pickup(_player: Node2D) -> void:
	GameManager.add_rupees(rupee_type as int)
