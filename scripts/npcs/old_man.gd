extends Node2D
## The Old Man NPC who gives the player the wooden sword.
## "IT'S DANGEROUS TO GO ALONE! TAKE THIS."

signal dialogue_started
signal dialogue_finished

const DIALOGUE_TEXT := "IT'S DANGEROUS TO GO ALONE! TAKE THIS."

# Detection range for triggering dialogue
const TRIGGER_DISTANCE := 40.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea

var has_given_sword := false
var dialogue_triggered := false
var player_ref: Node2D = null


func _ready() -> void:
	# Check if player already has sword (skip dialogue if returning)
	if GameManager.has_sword():
		has_given_sword = true
		dialogue_triggered = true


func _physics_process(_delta: float) -> void:
	if dialogue_triggered or has_given_sword:
		return

	# Check proximity to player
	if player_ref and global_position.distance_to(player_ref.global_position) < TRIGGER_DISTANCE:
		trigger_dialogue()


func trigger_dialogue() -> void:
	## Start the dialogue sequence
	if dialogue_triggered:
		return

	dialogue_triggered = true
	dialogue_started.emit()
	print("Old Man: Dialogue triggered!")

	# Find the dialogue box in the cave scene
	var cave = get_parent()
	var dialogue_box = cave.get_node_or_null("DialogueBox")
	print("Old Man: Found dialogue_box = ", dialogue_box)
	if dialogue_box and dialogue_box.has_method("show_text"):
		print("Old Man: Calling show_text()")
		dialogue_box.show_text(DIALOGUE_TEXT)
		# Connect to dialogue finished signal
		if dialogue_box.has_signal("text_finished"):
			dialogue_box.text_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		# No dialogue box, immediately show sword
		print("Old Man: No dialogue_box found, showing sword immediately")
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
	print("Old Man: Body entered detection area: ", body.name, " groups: ", body.get_groups())
	if body.is_in_group("player"):
		player_ref = body
		if not dialogue_triggered and not has_given_sword:
			trigger_dialogue()
