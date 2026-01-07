extends Node2D
## Universal enemy death effect - spawned at enemy position, auto-removes after animation.
## Usage: Any enemy can spawn this on death:
##   var death_effect = preload("res://scenes/enemies/enemy_death.tscn").instantiate()
##   death_effect.global_position = global_position
##   get_parent().add_child(death_effect)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("death")


func _on_animation_finished() -> void:
	queue_free()
