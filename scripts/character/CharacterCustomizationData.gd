## CharacterCustomizationData.gd
## Holds color customization attributes for the caveman character.
## Can serialize to/from user:// storage.

class_name CharacterCustomizationData
extends Resource

signal customization_changed

# ---------------------------------------------------------------------------
# Prehistoric Palette Options (for UI swatches)
# ---------------------------------------------------------------------------
const SKIN_PALETTE: Array[Color] = [
	Color(0.86, 0.68, 0.53), # Sunbaked Light
	Color(0.76, 0.54, 0.38), # Tanned Ochre
	Color(0.58, 0.38, 0.24), # Deep Earth
	Color(0.42, 0.26, 0.16), # Dark Mud
	Color(0.78, 0.48, 0.36), # Red Clay
	Color(0.65, 0.60, 0.54), # Ash Pale
]

const HAIR_PALETTE: Array[Color] = [
	Color(0.12, 0.09, 0.07), # Obsidian Black
	Color(0.32, 0.20, 0.12), # Mammoth Brown
	Color(0.55, 0.32, 0.15), # Rust Fox
	Color(0.78, 0.62, 0.35), # Straw Blonde
	Color(0.50, 0.48, 0.46), # Wolf Grey
	Color(0.88, 0.86, 0.82), # Bone White
]

const CLOTHING_PALETTE: Array[Color] = [
	Color(0.62, 0.40, 0.22), # Saber Pelt Brown
	Color(0.45, 0.35, 0.28), # Boar Hide Grey
	Color(0.25, 0.22, 0.20), # Midnight Fur
	Color(0.68, 0.30, 0.18), # Ochre Dye
	Color(0.36, 0.48, 0.30), # Moss Wrap
	Color(0.72, 0.58, 0.38), # Deer Leather
]

const ACCENT_PALETTE: Array[Color] = [
	Color(0.92, 0.88, 0.78), # Mammoth Ivory
	Color(0.85, 0.32, 0.22), # War Paint Red
	Color(0.28, 0.65, 0.62), # Cave Turquoise
	Color(0.85, 0.68, 0.25), # Amber Gem
	Color(0.30, 0.28, 0.26), # Flint Stone
	Color(0.70, 0.72, 0.75), # Quartz White
]

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
@export var skin_color: Color = Color(0.76, 0.54, 0.38):
	set(value):
		skin_color = value
		customization_changed.emit()

@export var hair_color: Color = Color(0.18, 0.12, 0.08):
	set(value):
		hair_color = value
		customization_changed.emit()

@export var clothing_color: Color = Color(0.62, 0.40, 0.22):
	set(value):
		clothing_color = value
		customization_changed.emit()

@export var accent_color: Color = Color(0.92, 0.88, 0.78):
	set(value):
		accent_color = value
		customization_changed.emit()

# ---------------------------------------------------------------------------
# Factory & Serialization
# ---------------------------------------------------------------------------
static func get_default() -> CharacterCustomizationData:
	var data := CharacterCustomizationData.new()
	data.skin_color = SKIN_PALETTE[1]
	data.hair_color = HAIR_PALETTE[1]
	data.clothing_color = CLOTHING_PALETTE[0]
	data.accent_color = ACCENT_PALETTE[0]
	return data

func to_dict() -> Dictionary:
	return {
		"skin_color": [skin_color.r, skin_color.g, skin_color.b, skin_color.a],
		"hair_color": [hair_color.r, hair_color.g, hair_color.b, hair_color.a],
		"clothing_color": [clothing_color.r, clothing_color.g, clothing_color.b, clothing_color.a],
		"accent_color": [accent_color.r, accent_color.g, accent_color.b, accent_color.a],
	}

func from_dict(dict: Dictionary) -> void:
	if dict.has("skin_color"):
		var v = dict["skin_color"]
		if v is Array and v.size() >= 4:
			skin_color = Color(v[0], v[1], v[2], v[3])
		elif v is String:
			skin_color = Color.from_string(v, skin_color)
	if dict.has("hair_color"):
		var v = dict["hair_color"]
		if v is Array and v.size() >= 4:
			hair_color = Color(v[0], v[1], v[2], v[3])
		elif v is String:
			hair_color = Color.from_string(v, hair_color)
	if dict.has("clothing_color"):
		var v = dict["clothing_color"]
		if v is Array and v.size() >= 4:
			clothing_color = Color(v[0], v[1], v[2], v[3])
		elif v is String:
			clothing_color = Color.from_string(v, clothing_color)
	if dict.has("accent_color"):
		var v = dict["accent_color"]
		if v is Array and v.size() >= 4:
			accent_color = Color(v[0], v[1], v[2], v[3])
		elif v is String:
			accent_color = Color.from_string(v, accent_color)

func save_to_file(file_path: String = "user://customization.json") -> Error:
	var json_str := JSON.stringify(to_dict(), "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(json_str)
	file.close()
	return OK

static func load_or_create(file_path: String = "user://customization.json") -> CharacterCustomizationData:
	var data := CharacterCustomizationData.new()
	if not FileAccess.file_exists(file_path):
		return get_default()
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return get_default()
	
	var content := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		data.from_dict(parsed)
	else:
		return get_default()
	
	return data
