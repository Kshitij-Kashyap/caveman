## CraftingMenu.gd
## Crafting Fire screen (screenshot panel 10: CRAFTING).
## Data-driven recipes (res://resources/crafting/*.tres) paid from the camp
## stockpile (ProgressionManager.stored_resources); results go to the
## crafting player's expedition inventory (or a `special` effect such as
## "glow_charge"). Station-gated: opened by TribeCamp's CraftingFire.
## Code-added by TribeCamp, so no .tscn edits are required.

class_name CraftingMenu
extends CanvasLayer

var _player: Player = null
var _recipes: Array[CraftingRecipe] = []
var _rows: Array[Dictionary] = [] # {recipe, cost_label, craft_btn}

var _root: PanelContainer = null
var _list: VBoxContainer = null
var _status: Label = null
var _stock_label: Label = null

func _ready() -> void:
	layer = 11
	_build_ui()
	visible = false
	_load_recipes()

func _load_recipes() -> void:
	_recipes.clear()
	var dir := DirAccess.open("res://resources/crafting/")
	if not dir:
		return
	var paths: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			paths.append("res://resources/crafting/" + fname)
		fname = dir.get_next()
	paths.sort()
	for p in paths:
		var res := load(p)
		if res is CraftingRecipe:
			_recipes.append(res)
	_ensure_rows()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Open / close
# ---------------------------------------------------------------------------
func is_open() -> bool:
	return visible

func open_for(player: Player) -> void:
	_player = player
	refresh()
	visible = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_menu() -> void:
	visible = false
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------------------------------------------------------------------------
# Content
# ---------------------------------------------------------------------------
func get_recipe_count() -> int:
	return _recipes.size()

func get_status() -> String:
	return _status.text if _status else ""

func can_craft(recipe_id: String) -> bool:
	var recipe := _find(recipe_id)
	if recipe == null:
		return false
	return _missing(recipe).is_empty() and _can_receive(recipe)

func craft_by_id(recipe_id: String) -> bool:
	var recipe := _find(recipe_id)
	if recipe == null:
		return false
	return _craft(recipe)

func refresh() -> void:
	if not is_inside_tree():
		return
	_update_stock()
	for r in _rows:
		var recipe: CraftingRecipe = r["recipe"]
		var missing := _missing(recipe)
		var cost_lbl := r["cost_label"] as Label
		cost_lbl.text = _cost_text(recipe, missing)
		var btn := r["craft_btn"] as Button
		btn.disabled = not missing.is_empty() or not _can_receive(recipe)

func _find(recipe_id: String) -> CraftingRecipe:
	for recipe in _recipes:
		if recipe.recipe_id == recipe_id:
			return recipe
	return null

func _missing(recipe: CraftingRecipe) -> Dictionary:
	var out := {}
	for item_id in recipe.cost:
		var need: int = int(recipe.cost[item_id])
		var have: int = int(ProgressionManager.stored_resources.get(item_id, 0))
		if have < need:
			out[item_id] = need - have
	return out

func _can_receive(recipe: CraftingRecipe) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if recipe.special == "glow_charge":
		return _player.glow_system != null and _player.glow_system.current_rocks < GlowRockSystem.MAX_ROCKS
	if recipe.result_item_id.is_empty():
		return false
	return _player.inventory != null

func _cost_text(recipe: CraftingRecipe, missing: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in recipe.cost:
		var need: int = int(recipe.cost[item_id])
		var have: int = int(ProgressionManager.stored_resources.get(item_id, 0))
		var mark := "✓" if have >= need else "✗"
		parts.append("%s %d/%d %s" % [mark, have, need, str(item_id).capitalize()])
	return "  ".join(parts)

func _craft(recipe: CraftingRecipe) -> bool:
	var missing := _missing(recipe)
	if not missing.is_empty():
		_status.text = "Missing: " + ", ".join(missing.keys())
		return false
	if not _can_receive(recipe):
		_status.text = "No room for the result (pack full or rocks maxed)."
		return false
	# Deliver first so a failed grant never eats materials.
	if recipe.special == "glow_charge":
		if not _player.glow_system.add_rock():
			_status.text = "Glow rocks already full."
			return false
	else:
		if not _player.inventory.add_item(recipe.result_item_id, recipe.result_qty):
			_status.text = "Pack too heavy for the result."
			return false
	if not ProgressionManager.spend_resources(recipe.cost):
		# Extremely rare race: refund the grant.
		if recipe.special == "":
			_player.inventory.remove_item(recipe.result_item_id, recipe.result_qty)
		_status.text = "Stockpile changed — try again."
		return false
	AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT_ORE)
	_status.text = "Crafted %s!" % recipe.result_name
	refresh()
	return true

func _update_stock() -> void:
	var parts: Array[String] = []
	for item_id in ProgressionManager.stored_resources:
		parts.append("%s: %d" % [str(item_id).capitalize(), int(ProgressionManager.stored_resources[item_id])])
	_stock_label.text = "Stockpile: " + ("  |  ".join(parts) if not parts.is_empty() else "Empty — deposit loot via extraction!")

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "CraftingPanel"
	_root.anchors_preset = Control.PRESET_CENTER
	_root.custom_minimum_size = Vector2(600, 440)
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.offset_left = -300.0
	_root.offset_right = 300.0
	_root.offset_top = -220.0
	_root.offset_bottom = 220.0
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
	title.text = "🔥  CRAFTING FIRE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_stock_label = Label.new()
	_stock_label.add_theme_font_size_override("font_size", 12)
	_stock_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.62, 1.0))
	_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_stock_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60, 1.0))
	vbox.add_child(_status)

	var close_btn := Button.new()
	close_btn.text = "CLOSE  (Esc)"
	close_btn.pressed.connect(close_menu)
	vbox.add_child(close_btn)

func _ensure_rows() -> void:
	if not _rows.is_empty() or _recipes.is_empty():
		return
	for recipe in _recipes:
		_list.add_child(_make_row(recipe))

func _make_row(recipe: CraftingRecipe) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.10, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = recipe.result_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70, 1.0))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = recipe.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.73, 0.62, 1.0))
	info.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 12)
	info.add_child(cost_lbl)

	var craft_btn := Button.new()
	craft_btn.text = "CRAFT"
	craft_btn.custom_minimum_size = Vector2(90, 0)
	craft_btn.pressed.connect(func(): _craft(recipe))
	hbox.add_child(craft_btn)

	_rows.append({"recipe": recipe, "cost_label": cost_lbl, "craft_btn": craft_btn})
	return panel
