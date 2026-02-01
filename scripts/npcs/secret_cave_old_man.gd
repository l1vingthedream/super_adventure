extends Node2D
## Old Man NPC for the secret item cave.
## Says "TAKE ANY ONE YOU WANT" when player approaches.

signal dialogue_started
signal dialogue_finished

const DIALOGUE_TEXT := "TAKE ANY ONE YOU WANT."
const TRIGGER_DISTANCE := 40.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea

var dialogue_triggered := false
var player_ref: Node2D = null


func _physics_process(_delta: float) -> void:
	if dialogue_triggered:
		return

	if player_ref and global_position.distance_to(player_ref.global_position) < TRIGGER_DISTANCE:
		trigger_dialogue()


func trigger_dialogue() -> void:
	if dialogue_triggered:
		return

	dialogue_triggered = true
	dialogue_started.emit()

	var cave = get_parent()
	var dialogue_box = cave.get_node_or_null("DialogueBox")
	if dialogue_box and dialogue_box.has_method("show_text"):
		dialogue_box.show_text(DIALOGUE_TEXT)
		if dialogue_box.has_signal("text_finished"):
			dialogue_box.text_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		_on_dialogue_finished()


func _on_dialogue_finished() -> void:
	dialogue_finished.emit()


func set_player(p: Node2D) -> void:
	player_ref = p


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		if not dialogue_triggered:
			trigger_dialogue()
