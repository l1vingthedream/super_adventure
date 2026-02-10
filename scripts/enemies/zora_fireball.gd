extends Area2D
## Zora fireball projectile - aimed projectile that travels toward player's position.
## Animated 4-frame sprite that cycles regardless of travel direction.

const SPEED := 90.0
const LIFETIME := 4.0
const SCREEN_WIDTH_PX := 256
const SCREEN_HEIGHT_PX := 176
const ANIM_FPS := 8.0

# 4-frame animation (8x16 each)
const FRAME_REGIONS := [
	Rect2(257, 11, 8, 16),
	Rect2(266, 11, 8, 16),
	Rect2(275, 11, 8, 16),
	Rect2(284, 11, 8, 16)
]

var direction := Vector2.DOWN  # Set by Zora before add_child
var lifetime_timer := 0.0
var anim_timer := 0.0
var anim_frame := 0
var origin_screen_bounds: Rect2

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	var screen_x := int(global_position.x / SCREEN_WIDTH_PX)
	var screen_y := int(global_position.y / SCREEN_HEIGHT_PX)
	origin_screen_bounds = Rect2(
		screen_x * SCREEN_WIDTH_PX,
		screen_y * SCREEN_HEIGHT_PX,
		SCREEN_WIDTH_PX,
		SCREEN_HEIGHT_PX
	)

	# Set initial sprite frame
	sprite.region_rect = FRAME_REGIONS[0]

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

	if not origin_screen_bounds.has_point(global_position):
		queue_free()
		return

	lifetime_timer += delta
	if lifetime_timer >= LIFETIME:
		queue_free()
		return

	# Animate through 4 frames
	anim_timer += delta
	if anim_timer >= 1.0 / ANIM_FPS:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4
		sprite.region_rect = FRAME_REGIONS[anim_frame]


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		queue_free()
