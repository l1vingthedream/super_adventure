extends CanvasLayer
## Lightweight debug overlay showing current screen coords and god mode status.

const SCREEN_LABEL_DURATION := 2.0

var screen_label: Label
var god_mode_label: Label
var screen_label_timer := 0.0
var last_screen := Vector2i(-1, -1)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	screen_label = Label.new()
	screen_label.position = Vector2(2, 58)
	screen_label.add_theme_font_size_override("font_size", 8)
	screen_label.add_theme_color_override("font_color", Color.YELLOW)
	screen_label.visible = false
	add_child(screen_label)

	god_mode_label = Label.new()
	god_mode_label.position = Vector2(2, 68)
	god_mode_label.add_theme_font_size_override("font_size", 8)
	god_mode_label.add_theme_color_override("font_color", Color.GREEN)
	god_mode_label.visible = false
	add_child(god_mode_label)


func _process(delta: float) -> void:
	var sm = get_tree().current_scene
	if sm and "current_screen" in sm:
		if sm.current_screen != last_screen:
			last_screen = sm.current_screen
			screen_label.text = "SCR %d,%d" % [sm.current_screen.x, sm.current_screen.y]
			screen_label.visible = true
			screen_label_timer = SCREEN_LABEL_DURATION

	if screen_label_timer > 0:
		screen_label_timer -= delta
		if screen_label_timer <= 0:
			screen_label.visible = false

	god_mode_label.visible = GameManager.debug_invincible
	if GameManager.debug_invincible:
		god_mode_label.text = "GOD MODE"
