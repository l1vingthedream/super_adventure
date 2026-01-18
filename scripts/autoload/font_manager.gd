extends Node
## Centralized font rendering system using Fonts.png asset.
## Provides 8x8 pixel characters in 4 color variants.

const FONTS_PATH := "res://assets/Fonts.png"
const CHAR_WIDTH := 8
const CHAR_HEIGHT := 8
const CELL_SIZE := 16  # Grid spacing in atlas: 8px char + 8px gap

enum FontColor { WHITE, BLUE, GREEN, RED }

# Row offset for each color variant (each color has 3 rows)
const COLOR_ROW_OFFSET := {
	FontColor.WHITE: 0,
	FontColor.BLUE: 3,
	FontColor.GREEN: 6,
	FontColor.RED: 9,
}

# Character mapping: character -> (column, row) in Fonts.png (white variant)
# Row 0: 0123456789ABCDEF
# Row 1: GHIJKLMNOPQRSTUV
# Row 2: WXYZ,!'&."?-
const CHAR_MAP := {
	# Row 0: Numbers and A-F
	"0": Vector2i(0, 0), "1": Vector2i(1, 0), "2": Vector2i(2, 0), "3": Vector2i(3, 0),
	"4": Vector2i(4, 0), "5": Vector2i(5, 0), "6": Vector2i(6, 0), "7": Vector2i(7, 0),
	"8": Vector2i(8, 0), "9": Vector2i(9, 0), "A": Vector2i(10, 0), "B": Vector2i(11, 0),
	"C": Vector2i(12, 0), "D": Vector2i(13, 0), "E": Vector2i(14, 0), "F": Vector2i(15, 0),
	# Row 1: G-V
	"G": Vector2i(0, 1), "H": Vector2i(1, 1), "I": Vector2i(2, 1), "J": Vector2i(3, 1),
	"K": Vector2i(4, 1), "L": Vector2i(5, 1), "M": Vector2i(6, 1), "N": Vector2i(7, 1),
	"O": Vector2i(8, 1), "P": Vector2i(9, 1), "Q": Vector2i(10, 1), "R": Vector2i(11, 1),
	"S": Vector2i(12, 1), "T": Vector2i(13, 1), "U": Vector2i(14, 1), "V": Vector2i(15, 1),
	# Row 2: W-Z and special characters (WXYZ,!'&."?-)
	"W": Vector2i(0, 2), "X": Vector2i(1, 2), "Y": Vector2i(2, 2), "Z": Vector2i(3, 2),
	",": Vector2i(4, 2), "!": Vector2i(5, 2), "'": Vector2i(6, 2), "&": Vector2i(7, 2),
	".": Vector2i(8, 2), '"': Vector2i(9, 2), "?": Vector2i(10, 2), "-": Vector2i(11, 2),
}

var fonts_texture: Texture2D


func _ready() -> void:
	fonts_texture = load(FONTS_PATH)


func get_char_region(character: String, color: FontColor = FontColor.WHITE) -> Rect2:
	## Get the texture region for a character in the specified color.
	## Returns empty Rect2 if character not found.
	var upper_char := character.to_upper()
	if upper_char not in CHAR_MAP:
		return Rect2()

	var char_pos: Vector2i = CHAR_MAP[upper_char]
	var row_offset: int = COLOR_ROW_OFFSET[color]

	return Rect2(
		char_pos.x * CELL_SIZE,
		(char_pos.y + row_offset) * CELL_SIZE,
		CHAR_WIDTH,
		CHAR_HEIGHT
	)


func has_character(character: String) -> bool:
	## Check if a character exists in the font.
	return character.to_upper() in CHAR_MAP


func create_text_sprites(text: String, color: FontColor = FontColor.WHITE, parent: Node = null) -> Array[Sprite2D]:
	## Create sprite nodes for each character in the text.
	## Returns array of sprites positioned horizontally (8px spacing).
	## If parent provided, sprites are added as children.
	var sprites: Array[Sprite2D] = []
	var x_offset := 0

	for i in range(text.length()):
		var char := text[i]

		if char == " ":
			x_offset += CHAR_WIDTH
			continue

		var region := get_char_region(char, color)
		if region == Rect2():
			x_offset += CHAR_WIDTH
			continue

		var sprite := Sprite2D.new()
		sprite.texture = fonts_texture
		sprite.region_enabled = true
		sprite.region_rect = region
		sprite.centered = false
		sprite.position = Vector2(x_offset, 0)

		if parent:
			parent.add_child(sprite)

		sprites.append(sprite)
		x_offset += CHAR_WIDTH

	return sprites


func get_text_width(text: String) -> int:
	## Calculate the pixel width of rendered text.
	return text.length() * CHAR_WIDTH
