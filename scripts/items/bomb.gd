extends Area2D
## Placed bomb - sits on ground, explodes after fuse timer.

const FUSE_DURATION := 2.0  # Seconds before explosion
const FLASH_START := 0.5    # Start flashing when this much time remains

var fuse_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("bombs")


func _physics_process(delta: float) -> void:
	fuse_timer += delta

	# Flash faster as fuse runs out
	var time_remaining := FUSE_DURATION - fuse_timer
	if time_remaining < FLASH_START:
		sprite.visible = int(fuse_timer * 10) % 2 == 0

	if fuse_timer >= FUSE_DURATION:
		_explode()


func _explode() -> void:
	# Spawn explosion effect at our position
	var explosion = preload("res://scenes/items/bomb_explosion.tscn").instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	queue_free()
