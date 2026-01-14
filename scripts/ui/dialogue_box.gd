extends CanvasLayer
## Dialogue box that displays text letter-by-letter using the NES Zelda font.

signal text_finished

const FONTS_PATH := "res://assets/Fonts.png"
const CHAR_WIDTH := 8
const CHAR_HEIGHT := 8
const CHAR_SPACING := 8  # Horizontal spacing between characters in texture

# Text display settings
const LETTER_DELAY := 0.05  # Seconds between each letter
const LINE_HEIGHT := 12  # Vertical spacing between lines

# Cave dialogue positioning (columns 4-13, rows 3-4)
const TEXT_AREA_LEFT := 64  # Column 4 * 16px tile size = 64
const TEXT_AREA_RIGHT := 208  # Column 13 * 16px = 208 (end of column 12)
const TEXT_AREA_WIDTH := 144  # 208 - 64
const ROW_3_Y := 48  # Row 3 * 16px = 48
const ROW_4_Y := 60  # Row 4 * 16px = 64, but use 60 for closer spacing

# Character mapping: character -> (column, row) in Fonts.png
# Row 0: 0123456789ABCDEF (white)
# Row 1: GHIJKLMNOPQRSTUV (white)
# Row 2: WXYZ,.!?'- (white) and more punctuation
const CHAR_MAP := {
	"0": Vector2i(0, 0), "1": Vector2i(1, 0), "2": Vector2i(2, 0), "3": Vector2i(3, 0),
	"4": Vector2i(4, 0), "5": Vector2i(5, 0), "6": Vector2i(6, 0), "7": Vector2i(7, 0),
	"8": Vector2i(8, 0), "9": Vector2i(9, 0), "A": Vector2i(10, 0), "B": Vector2i(11, 0),
	"C": Vector2i(12, 0), "D": Vector2i(13, 0), "E": Vector2i(14, 0), "F": Vector2i(15, 0),
	"G": Vector2i(0, 1), "H": Vector2i(1, 1), "I": Vector2i(2, 1), "J": Vector2i(3, 1),
	"K": Vector2i(4, 1), "L": Vector2i(5, 1), "M": Vector2i(6, 1), "N": Vector2i(7, 1),
	"O": Vector2i(8, 1), "P": Vector2i(9, 1), "Q": Vector2i(10, 1), "R": Vector2i(11, 1),
	"S": Vector2i(12, 1), "T": Vector2i(13, 1), "U": Vector2i(14, 1), "V": Vector2i(15, 1),
	"W": Vector2i(0, 2), "X": Vector2i(1, 2), "Y": Vector2i(2, 2), "Z": Vector2i(3, 2),
	",": Vector2i(4, 2), ".": Vector2i(5, 2), "!": Vector2i(6, 2), "?": Vector2i(7, 2),
	"'": Vector2i(8, 2), "-": Vector2i(9, 2),
}

var fonts_texture: Texture2D
var text_container: Control
var letter_sprites: Array[Sprite2D] = []
var current_lines: Array[String] = []  # Pre-split lines for centering
var current_line_index := 0
var current_char_index := 0
var letter_timer := 0.0
var is_displaying := false


func _ready() -> void:
	layer = 10  # Above game but same as pause menu
	visible = false

	fonts_texture = load(FONTS_PATH)

	# Create container for letter sprites
	text_container = Control.new()
	text_container.name = "TextContainer"
	add_child(text_container)


func _process(delta: float) -> void:
	if not is_displaying:
		return

	letter_timer += delta
	if letter_timer >= LETTER_DELAY:
		letter_timer = 0.0
		_show_next_letter()


func show_text(text: String) -> void:
	## Start displaying text letter by letter
	# Clear previous text
	for sprite in letter_sprites:
		sprite.queue_free()
	letter_sprites.clear()

	# Split text into lines (use newline or pre-defined split)
	var upper_text := text.to_upper()
	if "\n" in upper_text:
		current_lines.assign(upper_text.split("\n"))
	else:
		# Auto-split the old man dialogue
		current_lines = _split_into_lines(upper_text)

	current_line_index = 0
	current_char_index = 0
	letter_timer = 0.0
	is_displaying = true
	visible = true


func _split_into_lines(text: String) -> Array[String]:
	## Split text into centered lines for display
	# For the old man dialogue specifically
	var lines: Array[String] = []
	if "DANGEROUS" in text and "ALONE" in text:
		lines.append("ITS DANGEROUS TO GO")
		lines.append("ALONE! TAKE THIS")
	else:
		# Generic split at ~20 chars
		var words := text.split(" ")
		var current_line := ""
		for word in words:
			if current_line.length() + word.length() + 1 > 20:
				lines.append(current_line.strip_edges())
				current_line = word
			else:
				current_line += " " + word if current_line else word
		if current_line:
			lines.append(current_line.strip_edges())
	return lines


func _show_next_letter() -> void:
	## Display the next letter in the text
	if current_line_index >= current_lines.size():
		# All lines finished
		is_displaying = false
		text_finished.emit()
		return

	var current_line := current_lines[current_line_index]

	if current_char_index >= current_line.length():
		# Move to next line
		current_line_index += 1
		current_char_index = 0
		return

	var char := current_line[current_char_index]
	current_char_index += 1

	# Skip spaces (but advance position)
	if char == " ":
		return

	# Get character position in font texture
	if char not in CHAR_MAP:
		return  # Unknown character, skip

	var char_pos: Vector2i = CHAR_MAP[char]

	# Calculate centered position for this character
	var text_position := _calculate_centered_char_position(
		current_line, current_char_index - 1, current_line_index
	)

	# Create sprite for this character
	var sprite := Sprite2D.new()
	sprite.texture = fonts_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		char_pos.x * CHAR_SPACING,
		char_pos.y * CHAR_SPACING,
		CHAR_WIDTH,
		CHAR_HEIGHT
	)
	sprite.centered = false
	sprite.position = text_position

	text_container.add_child(sprite)
	letter_sprites.append(sprite)


func _calculate_centered_char_position(line: String, char_index: int, line_number: int) -> Vector2:
	## Calculate the pixel position for a character, centered in the text area
	# Calculate line width (excluding trailing spaces)
	var line_width := line.strip_edges().length() * CHAR_WIDTH

	# Center the line horizontally in the text area
	var center_x := TEXT_AREA_LEFT + (TEXT_AREA_WIDTH - line_width) / 2.0

	# Calculate x position for this character
	var x := center_x + char_index * CHAR_WIDTH

	# Y position based on line number (row 3 or row 4)
	var y := ROW_3_Y if line_number == 0 else ROW_4_Y

	return Vector2(x, y)


func hide_dialogue() -> void:
	## Hide the dialogue box
	visible = false
	is_displaying = false
