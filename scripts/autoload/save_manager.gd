extends Node
## Manages save/load functionality for 3 save slots.
## Persists player progress to user:// directory.

signal save_loaded(slot: int)
signal save_created(slot: int)
signal save_deleted(slot: int)

const SAVE_PATH := "user://save_data.json"
const MAX_SLOTS := 3
const MAX_NAME_LENGTH := 8

# Default values for new saves
const DEFAULT_HEARTS := 3
const DEFAULT_HEALTH := 3
const DEFAULT_RUPEES := 0
const DEFAULT_KEYS := 0
const DEFAULT_BOMBS := 0
const DEFAULT_SCREEN_X := 7
const DEFAULT_SCREEN_Y := 7

# Save data array (3 slots)
var save_slots: Array[Dictionary] = []

# Currently active slot (-1 = none selected)
var active_slot := -1


func _ready() -> void:
	_init_empty_slots()
	load_all_saves()


func _init_empty_slots() -> void:
	## Initialize save_slots array with empty dictionaries
	save_slots.clear()
	for i in range(MAX_SLOTS):
		save_slots.append({})


func load_all_saves() -> void:
	## Load save data from disk
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: No save file found, starting fresh")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: Failed to open save file")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("SaveManager: Failed to parse save file: " + json.get_error_message())
		return

	var data: Dictionary = json.data
	var slots: Array = data.get("slots", [])

	for i in range(mini(slots.size(), MAX_SLOTS)):
		if slots[i] is Dictionary and not slots[i].is_empty():
			save_slots[i] = slots[i]

	print("SaveManager: Loaded %d save slots" % _count_used_slots())


func save_to_disk() -> void:
	## Write all save data to disk
	var data := {
		"slots": save_slots,
		"version": 1
	}

	var json_text := JSON.stringify(data, "\t")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to write save file")
		return

	file.store_string(json_text)
	file.close()
	print("SaveManager: Saved to disk")


func create_new_save(slot: int, player_name: String) -> bool:
	## Create a new save file in the specified slot
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager: Invalid slot index: %d" % slot)
		return false

	if player_name.length() == 0 or player_name.length() > MAX_NAME_LENGTH:
		push_error("SaveManager: Invalid name length: %d" % player_name.length())
		return false

	save_slots[slot] = {
		"name": player_name,
		"hearts": DEFAULT_HEARTS,
		"health": DEFAULT_HEALTH,
		"rupees": DEFAULT_RUPEES,
		"keys": DEFAULT_KEYS,
		"bombs": DEFAULT_BOMBS,
		"screen_x": DEFAULT_SCREEN_X,
		"screen_y": DEFAULT_SCREEN_Y,
		"death_count": 0,
		"owned_items": [],
		"equipped_item": 0,
		"revealed_tiles": []
	}

	save_to_disk()
	save_created.emit(slot)
	print("SaveManager: Created new save '%s' in slot %d" % [player_name, slot])
	return true


func delete_save(slot: int) -> bool:
	## Delete the save file in the specified slot (Elimination mode)
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager: Invalid slot index: %d" % slot)
		return false

	if is_slot_empty(slot):
		return false

	var old_name: String = save_slots[slot].get("name", "")
	save_slots[slot] = {}
	save_to_disk()
	save_deleted.emit(slot)
	print("SaveManager: Deleted save '%s' from slot %d" % [old_name, slot])
	return true


func load_save(slot: int) -> bool:
	## Load a save slot and apply data to GameManager
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager: Invalid slot index: %d" % slot)
		return false

	if is_slot_empty(slot):
		push_error("SaveManager: Slot %d is empty" % slot)
		return false

	var data: Dictionary = save_slots[slot]
	active_slot = slot

	# Apply inventory data to GameManager
	GameManager.rupees = data.get("rupees", DEFAULT_RUPEES)
	GameManager.keys = data.get("keys", DEFAULT_KEYS)
	GameManager.bombs = data.get("bombs", DEFAULT_BOMBS)

	# Restore owned items
	GameManager.owned_items.clear()
	var owned: Array = data.get("owned_items", [])
	for item_value in owned:
		if item_value is int and item_value >= 0 and item_value < GameManager.Item.size():
			GameManager.owned_items.append(item_value as GameManager.Item)

	# Restore equipped item
	var equipped: int = data.get("equipped_item", 0)
	if equipped >= 0 and equipped < GameManager.Item.size():
		GameManager.equipped_item = equipped as GameManager.Item

	# Restore revealed tiles
	GameManager.revealed_tiles.clear()
	var revealed: Array = data.get("revealed_tiles", [])
	for key in revealed:
		if key is String:
			GameManager.revealed_tiles.append(key)

	save_loaded.emit(slot)
	print("SaveManager: Loaded save '%s' from slot %d" % [data.get("name", ""), slot])
	return true


func save_game() -> void:
	## Save current game state to the active slot
	if active_slot < 0 or active_slot >= MAX_SLOTS:
		push_warning("SaveManager: No active slot to save to")
		return

	if is_slot_empty(active_slot):
		push_warning("SaveManager: Active slot is empty, cannot save")
		return

	var data: Dictionary = save_slots[active_slot]

	# Save inventory from GameManager
	data["rupees"] = GameManager.rupees
	data["keys"] = GameManager.keys
	data["bombs"] = GameManager.bombs

	# Save owned items
	var owned: Array = []
	for item in GameManager.owned_items:
		owned.append(int(item))
	data["owned_items"] = owned
	data["equipped_item"] = int(GameManager.equipped_item)

	# Save revealed tiles
	data["revealed_tiles"] = GameManager.revealed_tiles.duplicate()

	# Save player position if available
	var player := get_tree().get_first_node_in_group("player")
	if player and "health" in player and "max_health" in player:
		data["health"] = player.health
		data["hearts"] = player.max_health

	# Save screen position from screen_manager
	var screen_manager := get_tree().current_scene
	if screen_manager and "current_screen" in screen_manager:
		data["screen_x"] = screen_manager.current_screen.x
		data["screen_y"] = screen_manager.current_screen.y

	save_to_disk()
	print("SaveManager: Game saved to slot %d" % active_slot)


func increment_death_count() -> void:
	## Increment death counter for active slot
	if active_slot < 0 or active_slot >= MAX_SLOTS:
		return
	if is_slot_empty(active_slot):
		return

	var count: int = save_slots[active_slot].get("death_count", 0)
	save_slots[active_slot]["death_count"] = count + 1


func is_slot_empty(slot: int) -> bool:
	## Check if a slot has no save data
	if slot < 0 or slot >= MAX_SLOTS:
		return true
	return save_slots[slot].is_empty()


func get_slot_data(slot: int) -> Dictionary:
	## Get save data for a specific slot (for display purposes)
	if slot < 0 or slot >= MAX_SLOTS:
		return {}
	return save_slots[slot].duplicate()


func get_slot_name(slot: int) -> String:
	## Get the player name for a slot
	if is_slot_empty(slot):
		return ""
	return save_slots[slot].get("name", "")


func get_slot_hearts(slot: int) -> int:
	## Get the heart container count for a slot
	if is_slot_empty(slot):
		return 0
	return save_slots[slot].get("hearts", DEFAULT_HEARTS)


func get_slot_death_count(slot: int) -> int:
	## Get death count for a slot
	if is_slot_empty(slot):
		return 0
	return save_slots[slot].get("death_count", 0)


func get_spawn_screen() -> Vector2i:
	## Get the screen position to spawn player at
	if active_slot < 0 or is_slot_empty(active_slot):
		return Vector2i(DEFAULT_SCREEN_X, DEFAULT_SCREEN_Y)

	var data: Dictionary = save_slots[active_slot]
	return Vector2i(
		data.get("screen_x", DEFAULT_SCREEN_X),
		data.get("screen_y", DEFAULT_SCREEN_Y)
	)


func get_spawn_health() -> int:
	## Get the health to spawn player with
	if active_slot < 0 or is_slot_empty(active_slot):
		return DEFAULT_HEALTH

	return save_slots[active_slot].get("health", DEFAULT_HEALTH)


func get_max_hearts() -> int:
	## Get the max heart containers for current save
	if active_slot < 0 or is_slot_empty(active_slot):
		return DEFAULT_HEARTS

	return save_slots[active_slot].get("hearts", DEFAULT_HEARTS)


func _count_used_slots() -> int:
	## Count non-empty save slots
	var count := 0
	for slot in save_slots:
		if not slot.is_empty():
			count += 1
	return count
