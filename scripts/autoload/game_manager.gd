extends Node
## Global game state manager for inventory and progression tracking.

# Inventory signals for HUD updates
signal rupees_changed(amount: int)
signal keys_changed(amount: int)
signal bombs_changed(amount: int)
signal arrows_changed(amount: int)
signal equipped_item_changed(item_name: String)

# Pause signals
signal game_paused
signal game_resumed

# Inventory limits
const MAX_RUPEES := 255
const MAX_KEYS := 255
const MAX_BOMBS := 16
const MAX_ARROWS := 255

# Item enum for equipped B-button item
enum Item { NONE, BOOMERANG, BOMBS, BOW, CANDLE, RECORDER, FOOD, LETTER, WAND }

# Current inventory state
var rupees := 0:
	set(value):
		rupees = clampi(value, 0, MAX_RUPEES)
		rupees_changed.emit(rupees)

var keys := 0:
	set(value):
		keys = clampi(value, 0, MAX_KEYS)
		keys_changed.emit(keys)

var bombs := 0:
	set(value):
		bombs = clampi(value, 0, MAX_BOMBS)
		bombs_changed.emit(bombs)

var arrows := 0:
	set(value):
		arrows = clampi(value, 0, MAX_ARROWS)
		arrows_changed.emit(arrows)

var equipped_item: Item = Item.NONE:
	set(value):
		equipped_item = value
		equipped_item_changed.emit(_item_to_string(value))

# Owned items (for inventory screen)
var owned_items: Array[Item] = []

# Pause state
var is_paused := false
var is_in_dungeon := false  # For Triforce vs Dungeon frame in pause menu


func _ready() -> void:
	# Allow processing even when game is paused (for pause toggle)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Emit initial values so HUD can display them
	rupees_changed.emit(rupees)
	keys_changed.emit(keys)
	bombs_changed.emit(bombs)
	arrows_changed.emit(arrows)
	equipped_item_changed.emit(_item_to_string(equipped_item))


const DEBUG_INPUTS_ENABLED := true  # Set to true to enable debug keys (1/2/3/4/5)

func _unhandled_input(event: InputEvent) -> void:
	# Handle pause toggle
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if not DEBUG_INPUTS_ENABLED:
		return
	# Debug inputs for testing inventory
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				add_rupees(10)
				print("DEBUG: Added 10 rupees. Total: ", rupees)
			KEY_2:
				add_keys(1)
				print("DEBUG: Added 1 key. Total: ", keys)
			KEY_3:
				add_bombs(1)
				print("DEBUG: Added 1 bomb. Total: ", bombs)
			KEY_4:
				# Give player all items for testing pause menu
				acquire_item(Item.BOOMERANG)
				acquire_item(Item.BOMBS)
				acquire_item(Item.BOW)
				acquire_item(Item.CANDLE)
				acquire_item(Item.RECORDER)
				acquire_item(Item.FOOD)
				acquire_item(Item.LETTER)
				acquire_item(Item.WAND)
				print("DEBUG: Acquired all items for testing")
			KEY_5:
				add_arrows(5)
				print("DEBUG: Added 5 arrows. Total: ", arrows)


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	game_paused.emit()


func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	game_resumed.emit()


func add_rupees(amount: int) -> void:
	rupees += amount


func spend_rupees(amount: int) -> bool:
	if rupees >= amount:
		rupees -= amount
		return true
	return false


func add_keys(amount: int) -> void:
	keys += amount


func use_key() -> bool:
	if keys > 0:
		keys -= 1
		return true
	return false


func add_bombs(amount: int) -> void:
	bombs += amount


func use_bomb() -> bool:
	if bombs > 0:
		bombs -= 1
		return true
	return false


func add_arrows(amount: int) -> void:
	arrows += amount


func use_arrow() -> bool:
	if arrows > 0:
		arrows -= 1
		return true
	return false


func acquire_item(item: Item) -> void:
	if item not in owned_items:
		owned_items.append(item)


func _item_to_string(item: Item) -> String:
	match item:
		Item.NONE: return "none"
		Item.BOOMERANG: return "boomerang"
		Item.BOMBS: return "bombs"
		Item.BOW: return "bow"
		Item.CANDLE: return "candle"
		Item.RECORDER: return "recorder"
		Item.FOOD: return "food"
		Item.LETTER: return "letter"
		Item.WAND: return "wand"
	return "none"
