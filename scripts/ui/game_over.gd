extends CanvasLayer
## Game Over screen with darkening effect and Game Over image.
## Triggered when player dies (player_died signal).
## Press Z to respawn at starting point.

const DARKEN_SHADER_PATH := "res://assets/shaders/game_over_darken.gdshader"
const GAME_OVER_IMAGE_PATH := "res://assets/Game_Over_Image.png"

# Timing
const DARKEN_DURATION := 1.5  # Seconds for screen to darken
const IMAGE_DELAY := 0.3      # Brief delay after darkening before showing image

# State
enum State { DARKENING, SHOW_IMAGE, WAITING_INPUT }
var current_state := State.DARKENING
var darken_progress := 0.0
var image_timer := 0.0

# Node references
var darken_overlay: ColorRect
var game_over_bg: ColorRect
var game_over_image: Sprite2D


func _ready() -> void:
	layer = 50  # Above game, below title/file select
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_game_over_screen()

	# Pause the game tree but allow this overlay to process
	get_tree().paused = true


func _build_game_over_screen() -> void:
	## Construct the game over UI

	# Full-screen darken overlay with shader
	darken_overlay = ColorRect.new()
	darken_overlay.size = Vector2(256, 232)
	darken_overlay.position = Vector2.ZERO
	darken_overlay.color = Color.WHITE  # Shader will handle the actual color

	var shader := load(DARKEN_SHADER_PATH) as Shader
	if shader:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("darken_progress", 0.0)
		darken_overlay.material = material

	add_child(darken_overlay)

	# Game Over background (matches image background color #ff371a)
	game_over_bg = ColorRect.new()
	game_over_bg.color = Color("#ff371a")
	game_over_bg.size = Vector2(256, 232)
	game_over_bg.position = Vector2.ZERO
	game_over_bg.visible = false
	add_child(game_over_bg)

	# Game Over image (hidden initially)
	var game_over_texture := load(GAME_OVER_IMAGE_PATH) as Texture2D
	if game_over_texture:
		game_over_image = Sprite2D.new()
		game_over_image.texture = game_over_texture
		game_over_image.centered = false
		game_over_image.position = Vector2.ZERO
		game_over_image.visible = false
		add_child(game_over_image)


func _process(delta: float) -> void:
	match current_state:
		State.DARKENING:
			_process_darkening(delta)
		State.SHOW_IMAGE:
			_process_show_image(delta)
		State.WAITING_INPUT:
			pass  # Just waiting for input


func _process_darkening(delta: float) -> void:
	## Gradually darken the screen
	darken_progress += delta / DARKEN_DURATION
	darken_progress = minf(darken_progress, 1.0)

	# Update shader
	if darken_overlay.material:
		darken_overlay.material.set_shader_parameter("darken_progress", darken_progress)

	if darken_progress >= 1.0:
		current_state = State.SHOW_IMAGE
		image_timer = 0.0


func _process_show_image(delta: float) -> void:
	## Brief delay before showing game over image
	image_timer += delta
	if image_timer >= IMAGE_DELAY:
		if game_over_bg:
			game_over_bg.visible = true
		if game_over_image:
			game_over_image.visible = true
		current_state = State.WAITING_INPUT


func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.WAITING_INPUT:
		return

	# Only respond to Z (attack) button
	if event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_respawn_player()


func _respawn_player() -> void:
	## Respawn player at starting point
	# Increment death count and save
	SaveManager.increment_death_count()
	SaveManager.save_game()

	# Find the player
	var player := get_tree().get_first_node_in_group("player")
	if player:
		# Reset player state
		player.health = player.max_health
		player.is_dead = false
		player.invincibility_timer = 0.0
		player.velocity = Vector2.ZERO
		player.knockback_velocity = Vector2.ZERO

		# Reset palette
		if player.sprite and player.sprite.material:
			player.sprite.material.set_shader_parameter("palette_frame", 0)

		# Emit health changed to update HUD
		player.health_changed.emit(player.health, player.max_health)

		# Respawn at starting position based on location
		if GameManager.is_in_dungeon:
			# TODO: Respawn at dungeon entrance when dungeons are implemented
			# For now, respawn at default overworld position
			_respawn_at_overworld_start(player)
		else:
			_respawn_at_overworld_start(player)

	# Unpause and remove this overlay
	get_tree().paused = false
	queue_free()


func _respawn_at_overworld_start(player: Node) -> void:
	## Respawn player at the overworld starting screen (7, 7)
	var screen_manager := get_tree().current_scene

	# Default starting position: same as scene default (1920, 1320) on screen (7, 7)
	const START_SCREEN := Vector2i(7, 7)
	const SPAWN_POSITION := Vector2(1920, 1320)  # Original player spawn from overworld.tscn

	# Set player position (must also set subpixel_position to prevent override)
	player.global_position = SPAWN_POSITION
	if "subpixel_position" in player:
		player.subpixel_position = SPAWN_POSITION

	# Update screen manager to starting screen
	if screen_manager and "current_screen" in screen_manager:
		screen_manager.current_screen = START_SCREEN
		if screen_manager.has_method("center_camera_on_screen"):
			screen_manager.center_camera_on_screen(START_SCREEN)
		# Clear and respawn enemies for the new screen
		if screen_manager.has_method("_clear_enemies"):
			screen_manager._clear_enemies()
		if screen_manager.has_method("_spawn_enemies_for_screen"):
			screen_manager._spawn_enemies_for_screen(START_SCREEN)
		# Update HUD minimap
		if screen_manager.hud:
			screen_manager.hud.update_minimap(START_SCREEN)
