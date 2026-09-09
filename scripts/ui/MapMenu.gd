## MapMenu.gd
## Cave chart screen (screenshot panel 11: MAP).
## Left: tribe region list with lock state (ProgressionManager.unlocked_regions).
## Right: live schematic of the current expedition's DungeonData (rooms colored
## by type, corridors, extraction marker, player marker), or a hint outside caves.
## Toggled with M. Code-added to the local Player (works in camp + dungeon).

class_name MapMenu
extends CanvasLayer

class MapDraw:
	extends Control
	var rooms: Array = []
	var corridors: Array = []
	var player_pos: Vector3 = Vector3.ZERO
	var has_player: bool = false
	var extraction_pos: Vector3 = Vector3.ZERO
	var has_extraction: bool = false

	func set_data(data: DungeonData, p_pos: Vector3, p_valid: bool) -> void:
		if data:
			rooms = data.rooms
			corridors = data.corridors
			extraction_pos = data.extraction_point
			has_extraction = true
		else:
			rooms = []
			corridors = []
			has_extraction = false
		player_pos = p_pos
		has_player = p_valid
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		draw_rect(rect, Color(0.05, 0.055, 0.07, 1.0))
		if rooms.is_empty():
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 28),
				"No cave charted — descend on an expedition.",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.68, 0.6, 1.0))
			return
		var min_p := Vector2(INF, INF)
		var max_p := Vector2(-INF, -INF)
		for room in rooms:
			var c := Vector2(room.world_position.x, room.world_position.z)
			var half: Vector2 = room.size * 0.5
			min_p = min_p.min(c - half)
			max_p = max_p.max(c + half)
		var span := (max_p - min_p)
		span.x = maxf(span.x, 1.0)
		span.y = maxf(span.y, 1.0)
		var scale_f: float = minf(rect.size.x / span.x, rect.size.y / span.y) * 0.92
		var to_map := func(world_xz: Vector2) -> Vector2:
			return rect.get_center() + (world_xz - (min_p + max_p) * 0.5) * scale_f
		for corr in corridors:
			draw_line(to_map.call(Vector2(corr.start_pos.x, corr.start_pos.z)),
				to_map.call(Vector2(corr.end_pos.x, corr.end_pos.z)),
				Color(0.35, 0.33, 0.30, 1.0), 3.0)
		for room in rooms:
			var c: Vector2 = to_map.call(Vector2(room.world_position.x, room.world_position.z))
			var half_px: Vector2 = room.size * 0.5 * scale_f
			draw_rect(Rect2(c - half_px, half_px * 2.0), _room_color(int(room.type)), true)
			draw_rect(Rect2(c - half_px, half_px * 2.0), Color(0.0, 0.0, 0.0, 0.8), false, 1.0)
		if has_extraction:
			var e: Vector2 = to_map.call(Vector2(extraction_pos.x, extraction_pos.z))
			draw_circle(e, 6.0, Color(0.3, 0.95, 0.5, 1.0))
		if has_player:
			var p: Vector2 = to_map.call(Vector2(player_pos.x, player_pos.z))
			var tri := PackedVector2Array([p + Vector2(0, -7), p + Vector2(5, 5), p + Vector2(-5, 5)])
			draw_colored_polygon(tri, Color(0.35, 0.65, 1.0, 1.0))

	func _room_color(type_id: int) -> Color:
		match type_id:
			0:
				return Color(0.35, 0.75, 0.40, 1.0) # ENTRANCE
			2:
				return Color(0.85, 0.65, 0.25, 1.0) # RESOURCE
			3:
				return Color(0.80, 0.30, 0.25, 1.0) # CREATURE_DEN
			4:
				return Color(0.70, 0.25, 0.75, 1.0) # BOSS
			5:
				return Color(0.30, 0.85, 0.85, 1.0) # EXTRACTION
			_:
				return Color(0.45, 0.45, 0.48, 1.0) # STANDARD

const REGIONS: Array[Dictionary] = [
	{"id": "shallow_caves", "name": "Shallow Caves", "desc": "Where every raid begins. Bats, rats and easy stone."},
	{"id": "deep_caverns", "name": "Deep Caverns", "desc": "Tighter tunnels, hungrier packs. Bring a spear."},
	{"id": "crystal_depths", "name": "Crystal Depths", "desc": "Glow crystal veins — and whatever guards them."},
	{"id": "boss_arena", "name": "Boss Arena", "desc": "Something enormous nests beyond the dark."},
]

var _root: PanelContainer = null
var _region_list: VBoxContainer = null
var _map_draw: MapDraw = null
var _hint: Label = null
var _refresh_cd: float = 0.0

func _ready() -> void:
	layer = 10
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			close_menu()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_cd -= delta
	if _refresh_cd <= 0.0:
		_refresh_cd = 0.5
		_update_schematic()

# ---------------------------------------------------------------------------
# Open / close
# ---------------------------------------------------------------------------
func is_open() -> bool:
	return visible

func toggle() -> void:
	if visible:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	_build_regions()
	_update_schematic()
	visible = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_menu() -> void:
	visible = false
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------------------------------------------------------------------------
# Content (test-friendly API)
# ---------------------------------------------------------------------------
func get_region_count() -> int:
	return REGIONS.size()

func get_unlocked_count() -> int:
	var n := 0
	for r in REGIONS:
		if str(r["id"]) in ProgressionManager.unlocked_regions:
			n += 1
	return n

func _get_player() -> Node3D:
	var p: Node = get_parent()
	while p != null:
		if p is CharacterBody3D:
			return p as Node3D
		p = p.get_parent()
	var lp := GameManager.get_local_player() as Node3D
	if lp != null and is_instance_valid(lp):
		return lp
	return null

func _update_schematic() -> void:
	var data := _find_dungeon_data()
	var p := _get_player()
	_map_draw.set_data(data, p.global_position if p else Vector3.ZERO, p != null)
	_hint.text = "▲ You   ● Cave Exit   ■ den/resource/entrance rooms   (M to close)" if data else "No cave charted — take an expedition!   (M to close)"

func _find_dungeon_data() -> DungeonData:
	var scene := get_tree().current_scene
	if scene and scene.has_method("get_dungeon_data"):
		return scene.get_dungeon_data() as DungeonData
	return null

func set_test_data(data: DungeonData) -> void:
	var p := _get_player()
	_map_draw.set_data(data, p.global_position if p else Vector3.ZERO, p != null)

func _build_regions() -> void:
	if not _region_list:
		return
	for c in _region_list.get_children():
		c.queue_free()
	for r in REGIONS:
		var unlocked := str(r["id"]) in ProgressionManager.unlocked_regions
		var lbl := Label.new()
		lbl.text = "%s %s\n%s" % ["🟢" if unlocked else "🔒", str(r["name"]), str(r["desc"])]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color",
			Color(0.9, 0.86, 0.72, 1.0) if unlocked else Color(0.5, 0.48, 0.44, 1.0))
		_region_list.add_child(lbl)

func get_player_marker() -> Vector2:
	# Map-space position of the player marker, for tests.
	var p := _get_player()
	if p == null:
		return Vector2.ZERO
	return Vector2(p.global_position.x, p.global_position.z)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "MapPanel"
	_root.anchors_preset = Control.PRESET_CENTER
	_root.custom_minimum_size = Vector2(640, 440)
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.offset_left = -320.0
	_root.offset_right = 320.0
	_root.offset_top = -220.0
	_root.offset_bottom = 220.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09, 0.97)
	style.border_color = Color(0.55, 0.65, 0.75, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_root.add_theme_stylebox_override("panel", style)
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_root.add_child(vbox)

	var title := Label.new()
	title.text = "🗺  CAVE CHART"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 10)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	_region_list = VBoxContainer.new()
	_region_list.custom_minimum_size = Vector2(220, 0)
	_region_list.add_theme_constant_override("separation", 8)
	split.add_child(_region_list)

	_map_draw = MapDraw.new()
	_map_draw.custom_minimum_size = Vector2(360, 300)
	_map_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_draw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_map_draw)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75, 1.0))
	vbox.add_child(_hint)
