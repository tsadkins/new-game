class_name ItemDefinition
extends Resource
## Static item template. No durability — items last until consumed or dropped.
## Properties are plain @export vars (not @export_enum) so other scripts can resolve them.

@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var type: String = "consumable"
@export var rarity: String = "common"
@export var base_damage: float = 0.0
@export var defense: int = 0
@export var health_restore: float = 0.0
@export var mana_restore: float = 0.0
@export var attack_speed_bonus: float = 0.0
@export var weight: float = 1.0
@export var icon_path: String = ""
@export var equip_slot: String = ""
@export var stack_size: int = 1
@export var sell_value: float = 0.0
@export var unique: bool = false


func get_equip_slot() -> String:
	return equip_slot


func is_equippable() -> bool:
	return not get_equip_slot().is_empty()


func is_consumable() -> bool:
	return type == "consumable"


func rarity_color() -> Color:
	match rarity:
		"uncommon":
			return Color(0.35, 0.85, 0.40)
		"rare":
			return Color(0.35, 0.55, 1.0)
		"legendary":
			return Color(1.0, 0.72, 0.20)
		_:
			return Color(0.75, 0.75, 0.78)


func make_icon() -> Texture2D:
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var tex := load(icon_path) as Texture2D
		if tex != null:
			return tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(rarity_color())
	for x in 32:
		img.set_pixel(x, 0, Color.BLACK)
		img.set_pixel(x, 31, Color.BLACK)
		img.set_pixel(0, x, Color.BLACK)
		img.set_pixel(31, x, Color.BLACK)
	return ImageTexture.create_from_image(img)
