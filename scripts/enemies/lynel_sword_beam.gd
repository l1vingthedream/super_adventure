extends Area2D
## Lynel sword beam projectile - travels in a cardinal direction, damages player on hit.
## Uses directional sprites with 4-frame animation.

const SPEED := 120.0
const LIFETIME := 3.0
const SCREEN_WIDTH_PX := 256
const SCREEN_HEIGHT_PX := 176
const ANIM_FPS := 8.0

# Horizontal sprites (16x16) - used for LEFT/RIGHT
const HORIZ_FRAMES := [
	Rect2(90, 110, 16, 16),
	Rect2(107, 110, 16, 16),
	Rect2(124, 110, 16, 16),
	Rect2(141, 110, 16, 16)
]

# Vertical sprites (8x16) - used for UP/DOWN
const VERT_FRAMES := [
	Rect2(90, 93, 8, 16),
	Rect2(99, 93, 8, 16),
	Rect2(108, 93, 8, 16),
	Rect2(117, 93, 8, 16)
]

var direction := Vector2.DOWN
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

	# Set initial sprite based on direction
	_setup_sprite_direction()
	_update_anim_frame()

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
		_update_anim_frame()


func _setup_sprite_direction() -> void:
	# Set flip flags based on direction
	if direction == Vector2.UP:
		sprite.flip_v = false
		sprite.flip_h = false
	elif direction == Vector2.DOWN:
		sprite.flip_v = true
		sprite.flip_h = false
	elif direction == Vector2.RIGHT:
		sprite.flip_h = false
		sprite.flip_v = false
	elif direction == Vector2.LEFT:
		sprite.flip_h = true
		sprite.flip_v = false


func _update_anim_frame() -> void:
	# Use vertical frames for UP/DOWN, horizontal frames for LEFT/RIGHT
	if direction == Vector2.UP or direction == Vector2.DOWN:
		sprite.region_rect = VERT_FRAMES[anim_frame]
	else:
		sprite.region_rect = HORIZ_FRAMES[anim_frame]


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		queue_free()
