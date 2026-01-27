extends Node2D
## A purchasable item displayed in the merchant shop.

signal purchase_attempted(item_type: String, price: int, quantity: int)

@export var item_type: String = ""  # "shield", "bombs", "arrows"
@export var price: int = 0
@export var quantity: int = 1

# Sprite regions in items_weapons.png
const ITEM_REGIONS := {
	"shield": Rect2(120, 0, 8, 16),
	"bombs": Rect2(136, 0, 8, 16),
	"arrows": Rect2(152, 0, 8, 16),
}
const RUPEE_REGION := Rect2(72, 0, 8, 16)

var item_sprite: Sprite2D
var price_container: Node2D


func _ready() -> void:
	_setup_item_display()
	_setup_price_display()
	_setup_selection_area()


func _setup_item_display() -> void:
	if item_type not in ITEM_REGIONS:
		push_warning("Unknown item type: " + item_type)
		return

	item_sprite = Sprite2D.new()
	item_sprite.texture = load("res://assets/items_weapons.png")
	item_sprite.region_enabled = true
	item_sprite.region_rect = ITEM_REGIONS[item_type]
	item_sprite.position = Vector2(0, 0)
	add_child(item_sprite)


func _setup_price_display() -> void:
	price_container = Node2D.new()
	price_container.position = Vector2(0, 16)  # Below item sprite, aligned with rupee X
	add_child(price_container)

	# Only show numeric price, centered below item
	var price_text := str(price)
	var text_width := price_text.length() * 8  # 8px per character
	var start_x := -text_width / 2.0  # Center the text

	var price_sprites := FontManager.create_text_sprites(price_text, FontManager.FontColor.WHITE)
	for i in range(price_sprites.size()):
		price_sprites[i].position.x = start_x + i * 8
		price_container.add_child(price_sprites[i])


func _setup_selection_area() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Player layer

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 32)  # Selection area around item
	shape.shape = rect
	area.add_child(shape)

	area.body_entered.connect(_on_body_entered)
	add_child(area)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		purchase_attempted.emit(item_type, price, quantity)
