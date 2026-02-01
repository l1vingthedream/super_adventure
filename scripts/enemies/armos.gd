extends CharacterBody2D
## Armos - immobile statue that activates when the player bumps into it.
## Once active, moves erratically and deals contact damage. 3 HP.

const MOVE_SPEED := 55.0
const HEALTH := 3
const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0
const ACTIVATE_DURATION := 0.5
const DIRECTION_CHANGE_TIME := 0.6

enum State { STATUE, ACTIVATING, WALKING }

signal activated(tile_cell: Vector2i)

var health := HEALTH
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0
var state := State.STATUE
var state_timer := 0.0
var move_timer := 0.0
var move_direction := Vector2.ZERO
var activate_flash_timer := 0.0
var tile_cell := Vector2i(-1, -1)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage


func _ready() -> void:
	hitbox.add_to_group("enemies")
	contact_damage.body_entered.connect(_on_contact_damage_body_entered)
	# Hide sprite while in statue state — the tilemap tile shows the correct visual
	sprite.visible = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Handle damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		palette_frame = 1 + int(damage_flash_timer * DAMAGE_FLASH_SPEED) % 3
		sprite.material.set_shader_parameter("palette_frame", palette_frame)
		if damage_flash_timer <= 0:
			palette_frame = 0
			sprite.material.set_shader_parameter("palette_frame", 0)

	match state:
		State.STATUE:
			var player = get_tree().get_first_node_in_group("player")
			if player and global_position.distance_to(player.global_position) <= 20.0:
				_activate()
		State.ACTIVATING:
			state_timer -= delta
			# Shake/flash effect
			activate_flash_timer += delta
			sprite.offset.x = sin(activate_flash_timer * 40.0) * 2.0
			if state_timer <= 0:
				sprite.offset.x = 0.0
				_enter_walking()
		State.WALKING:
			move_timer += delta
			if move_timer >= DIRECTION_CHANGE_TIME:
				move_timer = 0.0
				_pick_random_direction()
			velocity = move_direction * MOVE_SPEED
			move_and_slide()
			if get_slide_collision_count() > 0:
				_pick_random_direction()
			_update_animation()


func _activate() -> void:
	if state != State.STATUE:
		return
	state = State.ACTIVATING
	state_timer = ACTIVATE_DURATION
	activate_flash_timer = 0.0
	sprite.visible = true
	sprite.play("walk_down")
	if tile_cell != Vector2i(-1, -1):
		activated.emit(tile_cell)


func _enter_walking() -> void:
	state = State.WALKING
	_pick_random_direction()
	move_timer = 0.0


func _pick_random_direction() -> void:
	var angle := randf() * TAU
	move_direction = Vector2(cos(angle), sin(angle)).normalized()


func take_damage(amount: int) -> void:
	if is_dead:
		return
	if state == State.STATUE:
		_activate()
		return
	health -= amount
	damage_flash_timer = DAMAGE_FLASH_DURATION
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	var death_effect = preload("res://scenes/enemies/enemy_death.tscn").instantiate()
	death_effect.global_position = global_position
	get_parent().add_child(death_effect)
	DropSystem.spawn_drop(global_position, get_parent())
	queue_free()


func _on_contact_damage_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage"):
		if state == State.STATUE:
			_activate()
		else:
			body.take_damage(1, global_position)


func _update_animation() -> void:
	if move_direction.y < 0:
		sprite.play("walk_up")
	else:
		sprite.play("walk_down")
