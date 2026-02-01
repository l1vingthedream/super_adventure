extends Area2D
## Bomb explosion - deals damage to enemies and destroys cracked walls.

const EXPLOSION_DAMAGE := 2

var has_dealt_damage := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("explode")

	# Deal damage on first frame
	call_deferred("_deal_damage")


func _deal_damage() -> void:
	if has_dealt_damage:
		return
	has_dealt_damage = true

	# Damage all enemies in radius
	for area in get_overlapping_areas():
		if area.is_in_group("enemies"):
			var enemy = area.get_parent()
			if enemy.has_method("take_damage"):
				enemy.take_damage(EXPLOSION_DAMAGE)

	# Destroy cracked walls (for future implementation)
	for area in get_overlapping_areas():
		if area.is_in_group("crackable"):
			if area.has_method("destroy"):
				area.destroy()

	# Check for bombable tiles to reveal
	var screen_manager = get_tree().current_scene
	if screen_manager and screen_manager.has_method("try_bomb_reveal"):
		screen_manager.try_bomb_reveal(global_position)


func _on_animation_finished() -> void:
	queue_free()
