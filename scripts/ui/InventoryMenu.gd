## InventoryMenu.gd
## Expedition inventory screen (screenshot panel 9: INVENTORY).
## Grid of carried items with detail panel, Use (consumables) and Drop.
## Bound to the local player's InventoryComponent; toggled with Tab.
## Code-added to the local Player only (see Player._ready), so it works in
## camp, dungeon and test scenes without .tscn edits.

class_name InventoryMenu
extends CanvasLayer

const ICONS := {
	"meat": "🍖",
	"roast_meat": "🍗",
	"hide": "🟫",
	"wood": "🪵",
	"stone": "🪨",
	"flint": "🔸",
	"crystal": "💎",
	"bone": "🦴",
	"copper": "🟠",
	"flint_spear": "🗡",
	"fire_torch": "🔥",
	"stone_axe": "🪓",
	"stone_pickaxe": "⛏",
	"stone_wheel": "🛞",
}

const HEAL_VALUES := {
	"roast_meat": 30.0,
}

var _player: Player = null
var _inv: PlayerInventory = null
var _defs: Dictionary = {}

var _root: PanelContainer = null
var _grid: GridContainer = null
var _detail: Label = null
var _weight_bar: ProgressBar = null
var _status: Label = null
var _use_btn: Button = null
var _drop_btn: Button = null
var _selected_id: String = ""
var _slot_buttons: Array[Button] = []

func _ready() -> void:
	layer = 10
	_build_ui()
	visible = false
	_load_defs()
	_bind_player()

func _load_defs() -> void:
	var dir := DirAccess.open("res://resources/items/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load("res://resources/items/" + fname)
			if res is ItemDefinition:
				_defs[res.item_id] = res
		fname = dir.get_next()

func _bind_player() -> void:
	if not is_inside_tree():
		return
	_player = GameManager.get_local_player() as Player
	if _player == null:
		await get_tree().create_timer(0.3).timeout
		_bind_player()
		return
	_inv = _player.inventory as PlayerInventory
	if _inv:
		_inv.inventory_changed.connect(refresh)
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			close_menu()
			get_viewport().set_input_as_handled()

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
	_bind_player_deferred()
	refresh()
	visible = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_menu() -> void:
	visible = false
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _bind_player_deferred() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.get_local_player() as Player
		if _player:
			_inv = _player.inventory as PlayerInventory
			if _inv and not _inv.inventory_changed.is_connected(refresh):
				_inv.inventory_changed.connect(refresh)

# ---------------------------------------------------------------------------
# Content
# ---------------------------------------------------------------------------
func get_item_count() -> int:
	return _inv.get_all_items().size() if _inv else 0

func get_selected_id() -> String:
	return _selected_id

func refresh() -> void:
	if not is_inside_tree():
		return
	for b in _slot_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_slot_buttons.clear()
	if _inv == null:
		_update_detail()
		_update_weight()
		return
	var items := _inv.get_all_items()
	var ids := items.keys()
	ids.sort()
	for item_id in ids:
		_slot_buttons.append(_make_slot(str(item_id), int(items[item_id])))
	if not _selected_id in items and not ids.is_empty():
		_selected_id = str(ids[0])
	if ids.is_empty():
		_selected_id = ""
	_update_detail()
	_update_weight()
	_update_buttons()

func _make_slot(item_id: String, qty: int) -> Button:
	var b := Button.new()
	b.text = "%s %s x%d" % [_icon(item_id), _display_name(item_id), qty]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = (item_id == _selected_id)
	b.set_meta("item_id", item_id)
	b.pressed.connect(func(): _select(item_id))
	_grid.add_child(b)
	return b

func _select(item_id: String) -> void:
	_selected_id = item_id
	for b in _slot_buttons:
		if is_instance_valid(b):
			b.set_pressed_no_signal(str(b.get_meta("item_id")) == item_id)
	_update_detail()
	_update_buttons()

func _icon(item_id: String) -> String:
	return str(ICONS.get(item_id, "📦"))

func _display_name(item_id: String) -> String:
	var def := _defs.get(item_id) as ItemDefinition
	if def and not def.item_name.is_empty():
		return def.item_name
	return item_id.capitalize().replace("_", " ")

func _describe(item_id: String) -> String:
	var def := _defs.get(item_id) as ItemDefinition
	if def and not def.description.is_empty():
		return def.description
	return "No tribe records for this item yet."

func _update_detail() -> void:
	if _selected_id.is_empty() or _inv == null:
		_detail.text = "Empty pack — mine, chop and hunt to fill it."
		return
	var qty := _inv.get_quantity(_selected_id)
	var def := _defs.get(_selected_id) as ItemDefinition
	var w_each := def.weight if def else 1.0
	_detail.text = "%s %s\nQty: %d  (%.1f kg each)\n\n%s" % [
		_icon(_selected_id), _display_name(_selected_id), qty, w_each, _describe(_selected_id)]

func _update_weight() -> void:
	if _inv == null:
		_weight_bar.max_value = 1.0
		_weight_bar.value = 0.0
		_status.text = "No pack bound."
		return
	_weight_bar.max_value = _inv.max_carry_weight
	_weight_bar.value = _inv.current_weight
	_status.text = "Carrying %.1f / %.1f kg  (Tab to close)" % [_inv.current_weight, _inv.max_carry_weight]

func _update_buttons() -> void:
	var def := _defs.get(_selected_id) as ItemDefinition
	_use_btn.disabled = not (def and def.item_type == ItemDefinition.ItemType.CONSUMABLE)
	_drop_btn.disabled = _selected_id.is_empty()

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
func use_selected() -> bool:
	if _selected_id.is_empty() or _inv == null or _player == null:
		return false
	var def := _defs.get(_selected_id) as ItemDefinition
	if not (def and def.item_type == ItemDefinition.ItemType.CONSUMABLE):
		_status.text = "That cannot be eaten."
		return false
	if not _inv.has_item(_selected_id, 1):
		return false
	_inv.remove_item(_selected_id, 1)
	var heal: float = float(HEAL_VALUES.get(_selected_id, 10.0))
	_player.heal(heal)
	AudioManager.play_sfx(AudioManager.SFX.ITEM_PICKUP)
	_status.text = "Ate %s (+%d HP)." % [_display_name(_selected_id), int(heal)]
	refresh()
	return true

func drop_selected() -> bool:
	if _selected_id.is_empty() or _inv == null or _player == null:
		return false
	if not multiplayer.is_server():
		_status.text = "Dropping works for the host only (v1)."
		return false
	if not _inv.has_item(_selected_id, 1):
		return false
	_inv.remove_item(_selected_id, 1)
	var scene := load("res://scenes/items/LootItem.tscn") as PackedScene
	if scene:
		var item := scene.instantiate() as LootItem
		item.name = "LootItem"
		item.pickup_delay = 1.0
		get_tree().current_scene.add_child(item, true)
		var fwd: Vector3 = -_player.global_transform.basis.z
		fwd.y = 0.0
		if fwd.is_zero_approx():
			fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		item.global_position = _player.global_position + fwd * 1.5 + Vector3.UP * 0.6
		item.setup(_selected_id, 1)
		item.apply_central_impulse((fwd + Vector3.UP * 0.3).normalized() * 3.0)
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	refresh()
	return true

# ---------------------------------------------------------------------------
# UI construction (code-built, matching HUD tool-dock style)
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "InventoryPanel"
	_root.anchors_preset = Control.PRESET_CENTER
	_root.custom_minimum_size = Vector2(560, 420)
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.offset_left = -280.0
	_root.offset_right = 280.0
	_root.offset_top = -210.0
	_root.offset_bottom = 210.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.97)
	style.border_color = Color(0.85, 0.65, 0.25, 1.0)
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
	title.text = "🎒  INVENTORY"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 10)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(200, 0)
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76, 1.0))
	right.add_child(_detail)

	_use_btn = Button.new()
	_use_btn.text = "EAT / USE"
	_use_btn.pressed.connect(use_selected)
	right.add_child(_use_btn)

	_drop_btn = Button.new()
	_drop_btn.text = "DROP 1"
	_drop_btn.pressed.connect(drop_selected)
	right.add_child(_drop_btn)

	_weight_bar = ProgressBar.new()
	_weight_bar.custom_minimum_size = Vector2(0, 14)
	_weight_bar.show_percentage = false
	vbox.add_child(_weight_bar)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60, 1.0))
	vbox.add_child(_status)
