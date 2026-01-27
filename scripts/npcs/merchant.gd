extends Node2D
## Merchant NPC who sells items to the player.

const DIALOGUE_TEXT := "BUY SOMETHIN' WILL YA!"

var player: CharacterBody2D
var dialogue_box: CanvasLayer
var has_shown_dialogue := false


func _ready() -> void:
	# Get dialogue box reference from parent cave
	var cave = get_parent()
	if cave and cave.has_node("DialogueBox"):
		dialogue_box = cave.get_node("DialogueBox")


func set_player(p: CharacterBody2D) -> void:
	player = p


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		trigger_dialogue()


func trigger_dialogue() -> void:
	if not dialogue_box:
		return

	# Show dialogue (can repeat each time player approaches)
	dialogue_box.show_text(DIALOGUE_TEXT)
	has_shown_dialogue = true
