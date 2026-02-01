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

# Sword signal
signal sword_changed(sword_type: Sword)

# Inventory limits
const MAX_RUPEES := 255
const MAX_KEYS := 255
const MAX_BOMBS := 16
const MAX_ARROWS := 255

# Item enum for equipped B-button item
enum Item { NONE, BOOMERANG, BOMBS, BOW, CANDLE, RECORDER, FOOD, LETTER, WAND }

# Sword enum for equipped weapon
enum Sword { NONE, WOODEN, WHITE, MAGICAL }

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

# Current sword (weapon equipment)
var current_sword: Sword = Sword.NONE:
	set(value):
		current_sword = value
		sword_changed.emit(current_sword)

# Pause state
var is_paused := false
var is_in_dungeon := false  # For Triforce vs Dungeon frame in pause menu

# Cave/interior return state
var returning_from_cave := false
var cave_exit_screen := Vector2i(7, 7)  # Screen to return to
var cave_exit_tile := Vector2i(4, 1)  # Tile position within screen (0-based)

# Shop/merchant state
var has_purchased_bombs := false  # Unlocks bomb drops from enemies
var has_shield := false  # Player owns a shield

# Debug state
var debug_invincible := false
var debug_warp_menu: Node = null


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
			KEY_6:
				# Add 3 heart containers for testing white sword requirement
				var player = get_tree().get_first_node_in_group("player")
				if player and "max_health" in player:
					player.max_health += 3
					player.health = player.max_health  # Heal to full
					if player.has_signal("health_changed"):
						player.health_changed.emit(player.health, player.max_health)
					print("DEBUG: Added 3 heart containers. Max health: ", player.max_health)
			KEY_8:
				var sm = get_tree().current_scene
				if sm and sm.has_method("_spawn_enemies_for_screen") and "current_screen" in sm:
					sm._spawn_enemies_for_screen(sm.current_screen)
					print("DEBUG: Respawned enemies on screen ", sm.current_screen)
			KEY_9:
				debug_invincible = not debug_invincible
				print("DEBUG: God mode ", "ON" if debug_invincible else "OFF")
			KEY_0:
				_toggle_warp_menu()
			KEY_7:
				# Teleport to merchant cave screen (15, 6), tile (4, 4)
				var screen_manager = get_tree().current_scene
				var player = screen_manager.get_node_or_null("Player") if screen_manager else null
				if player and screen_manager and screen_manager.has_method("center_camera_on_screen"):
					var target_screen := Vector2i(15, 6)
					var target_tile := Vector2i(4, 4)
					var screen_width := 256
					var screen_height := 176
					var tile_size := 16
					# Calculate screen origin
					var screen_origin := Vector2(
						target_screen.x * screen_width,
						target_screen.y * screen_height
					)
					# Position player at tile center
					var new_pos := Vector2(
						screen_origin.x + target_tile.x * tile_size + tile_size / 2.0,
						screen_origin.y + target_tile.y * tile_size + tile_size / 2.0
					)
					player.global_position = new_pos
					# Must also set subpixel_position or player snaps back
					if "subpixel_position" in player:
						player.subpixel_position = new_pos
					screen_manager.current_screen = target_screen
					screen_manager.center_camera_on_screen(target_screen)
					print("DEBUG: Player node: ", player.name, " at ", player.global_position)
					print("DEBUG: Camera at: ", screen_manager.camera.position if "camera" in screen_manager else "unknown")
				else:
					print("DEBUG: Cannot teleport - player: ", player, " screen_manager: ", screen_manager)


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


func acquire_sword(sword_type: Sword) -> void:
	## Grant a sword to the player (only upgrades, never downgrades)
	if sword_type > current_sword:
		current_sword = sword_type


func has_sword() -> bool:
	## Check if player has any sword equipped
	return current_sword != Sword.NONE


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


func _toggle_warp_menu() -> void:
	if not debug_warp_menu:
		debug_warp_menu = preload("res://scenes/ui/debug_warp_menu.tscn").instantiate()
		add_child(debug_warp_menu)
	if debug_warp_menu.is_open:
		debug_warp_menu.close()
	else:
		debug_warp_menu.open()
