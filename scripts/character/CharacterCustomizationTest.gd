## CharacterCustomizationTest.gd
## CHARACTER_CUSTOMIZATION_TEST validation scene (spec section 20).
## Caveman + four palette buttons (Skin/Hair/Clothing/Accent) that cycle the
## CharacterCustomizationData palettes and push them live into the mesh.
## Keys 1-4 also cycle. No full menu — character-side system only.

class_name CharacterCustomizationTest
extends Node3D

var _caveman: Caveman = null
var _data: CharacterCustomizationData = null
var _idx := {"skin": 1, "hair": 1, "clothing": 0, "accent": 0}
var _label: Label = null

func _ready() -> void:
	_caveman = get_node_or_null("ModelPivot/Caveman") as Caveman
	_label = get_node_or_null("UI/Panel/InfoLabel") as Label
	_data = CharacterCustomizationData.get_default()
	_apply()
	_wire_buttons()

func _wire_buttons() -> void:
	var pairs: Array = [
		["UI/Panel/SkinButton", "skin"],
		["UI/Panel/HairButton", "hair"],
		["UI/Panel/ClothingButton", "clothing"],
		["UI/Panel/AccentButton", "accent"],
	]
	for p in pairs:
		var btn := get_node_or_null(str(p[0])) as Button
		if btn:
			var key := str(p[1])
			btn.pressed.connect(func(): _cycle(key))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_cycle("skin")
			KEY_2:
				_cycle("hair")
			KEY_3:
				_cycle("clothing")
			KEY_4:
				_cycle("accent")

func _cycle(key: String) -> void:
	match key:
		"skin":
			_idx["skin"] = (int(_idx["skin"]) + 1) % CharacterCustomizationData.SKIN_PALETTE.size()
			_data.skin_color = CharacterCustomizationData.SKIN_PALETTE[int(_idx["skin"])]
		"hair":
			_idx["hair"] = (int(_idx["hair"]) + 1) % CharacterCustomizationData.HAIR_PALETTE.size()
			_data.hair_color = CharacterCustomizationData.HAIR_PALETTE[int(_idx["hair"])]
		"clothing":
			_idx["clothing"] = (int(_idx["clothing"]) + 1) % CharacterCustomizationData.CLOTHING_PALETTE.size()
			_data.clothing_color = CharacterCustomizationData.CLOTHING_PALETTE[int(_idx["clothing"])]
		"accent":
			_idx["accent"] = (int(_idx["accent"]) + 1) % CharacterCustomizationData.ACCENT_PALETTE.size()
			_data.accent_color = CharacterCustomizationData.ACCENT_PALETTE[int(_idx["accent"])]
	_apply()

func _apply() -> void:
	if _caveman:
		_caveman.apply_customization(_data)
	if _label:
		_label.text = "Skin %d/%d  Hair %d/%d  Clothing %d/%d  Accent %d/%d" % [
			int(_idx["skin"]) + 1, CharacterCustomizationData.SKIN_PALETTE.size(),
			int(_idx["hair"]) + 1, CharacterCustomizationData.HAIR_PALETTE.size(),
			int(_idx["clothing"]) + 1, CharacterCustomizationData.CLOTHING_PALETTE.size(),
			int(_idx["accent"]) + 1, CharacterCustomizationData.ACCENT_PALETTE.size(),
		]
