extends Node2D
## The Old Man NPC who gives the player the white sword.
## Requires 5 hearts to receive the sword.
## "MASTER USING THIS AND / YOU CAN HAVE THIS."

signal dialogue_started
signal dialogue_finished

const DIALOGUE_TEXT := "MASTER USING THIS AND\nYOU CAN HAVE THIS."
const REQUIRED_HEARTS := 5

# Detection range for triggering dialogue
const TRIGGER_DISTANCE := 40.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea

var has_given_sword := false
var dialogue_triggered := false
var player_ref: Node2D = null


func _ready() -> void:
	# Check if player already has white sword or better (skip dialogue if returning)
	if GameManager.current_sword >= GameManager.Sword.WHITE:
		has_given_sword = true
		dialogue_triggered = true


func _physics_process(_delta: float) -> void:
	if dialogue_triggered or has_given_sword:
		return

	# Check proximity to player
	if player_ref and global_position.distance_to(player_ref.global_position) < TRIGGER_DISTANCE:
		trigger_dialogue()


func trigger_dialogue() -> void:
	## Start the dialogue sequence (only if player has enough hearts)
	if dialogue_triggered:
		return

	# Check heart requirement (player must have 5+ heart containers)
	if not player_ref or not "max_health" in player_ref:
		return
	if player_ref.max_health < REQUIRED_HEARTS:
		return  # Not enough hearts, don't trigger dialogue

	dialogue_triggered = true
	dialogue_started.emit()

	# Find the dialogue box in the cave scene
	var cave = get_parent()
	var dialogue_box = cave.get_node_or_null("DialogueBox")
	if dialogue_box and dialogue_box.has_method("show_text"):
		dialogue_box.show_text(DIALOGUE_TEXT)
		# Connect to dialogue finished signal
		if dialogue_box.has_signal("text_finished"):
			dialogue_box.text_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		# No dialogue box, immediately show sword
		_on_dialogue_finished()


func _on_dialogue_finished() -> void:
	## Called when dialogue text finishes displaying
	has_given_sword = true
	dialogue_finished.emit()

	# Tell cave to show the sword pickup
	var cave = get_parent()
	if cave.has_method("show_sword_pickup"):
		cave.show_sword_pickup()


func set_player(p: Node2D) -> void:
	## Set reference to player for proximity detection
	player_ref = p


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		if not dialogue_triggered and not has_given_sword:
			trigger_dialogue()
