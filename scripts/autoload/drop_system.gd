extends Node
## Manages item drop logic for enemies and other sources.

# Preload all pickup scenes
const PICKUP_SCENES := {
	"rupee_yellow": preload("res://scenes/pickups/rupee.tscn"),
	"rupee_blue": preload("res://scenes/pickups/rupee.tscn"),
	"heart": preload("res://scenes/pickups/heart.tscn"),
	"bomb": preload("res://scenes/pickups/bomb_pickup.tscn"),
	"arrow": preload("res://scenes/pickups/arrow.tscn"),
	"key": preload("res://scenes/pickups/key.tscn"),
}

# Drop tables - weights determine relative probability
# Keys are EXCLUDED from general enemy drops
const GENERAL_DROP_TABLE := {
	"nothing": 50,      # 50% chance of no drop
	"rupee_yellow": 30, # Common rupee (value: 1)
	"rupee_blue": 5,    # Rare rupee (value: 5)
	"heart": 10,        # Health recovery
	"bomb": 3,          # Consumable
	"arrow": 2,         # Consumable (if player has bow)
}

# Placeholder drop table for dungeon enemies (includes keys)
const DUNGEON_ENEMY_DROP_TABLE := {
	"nothing": 40,
	"rupee_yellow": 20,
	"rupee_blue": 10,
	"heart": 12,
	"bomb": 5,
	"arrow": 5,
	"key": 8,  # Keys CAN drop from dungeon enemies
}


func roll_drop(drop_table: Dictionary = GENERAL_DROP_TABLE) -> String:
	## Roll for a drop using weighted random selection.
	## Returns the item key or "nothing".
	## Bombs only drop if player has purchased them from merchant.
	var effective_table := drop_table.duplicate()

	# Gate bomb drops behind purchase flag
	if not GameManager.has_purchased_bombs and "bomb" in effective_table:
		effective_table["nothing"] += effective_table["bomb"]
		effective_table.erase("bomb")

	var total_weight := 0
	for weight in effective_table.values():
		total_weight += weight

	var roll := randi() % total_weight
	var cumulative := 0

	for item_key in effective_table:
		cumulative += effective_table[item_key]
		if roll < cumulative:
			return item_key

	return "nothing"


func spawn_drop(drop_position: Vector2, parent: Node, drop_table: Dictionary = GENERAL_DROP_TABLE) -> void:
	## Roll for and spawn a drop at the given position.
	var drop_key := roll_drop(drop_table)

	if drop_key == "nothing":
		return

	spawn_specific_drop(drop_position, parent, drop_key)


func spawn_specific_drop(drop_position: Vector2, parent: Node, drop_key: String) -> void:
	## Spawn a specific drop (for forced drops, chests, etc.)
	if drop_key not in PICKUP_SCENES:
		push_warning("Unknown drop key: " + drop_key)
		return

	var pickup: Node2D = PICKUP_SCENES[drop_key].instantiate()
	pickup.global_position = drop_position

	# Configure rupee type based on key
	if drop_key == "rupee_blue" and pickup.has_method("set_rupee_type"):
		pickup.set_rupee_type(RupeePickup.RupeeType.BLUE)

	parent.add_child(pickup)


func spawn_forced_key(drop_position: Vector2, parent: Node) -> void:
	## Spawn a key (for dungeon-specific drops, mini-bosses, etc.)
	spawn_specific_drop(drop_position, parent, "key")
