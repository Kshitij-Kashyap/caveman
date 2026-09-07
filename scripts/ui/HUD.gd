## HUD.gd
## In-game heads-up display.
## Displays stylized health, stamina, carry weight, currency, glow rocks,
## status effect indicators, and quest tracker.

extends CanvasLayer

# ---------------------------------------------------------------------------
# Node References
# ---------------------------------------------------------------------------
@onready var _health_bar: ProgressBar = $BottomLeft/HBox/VBox/HealthBar
@onready var _stamina_bar: ProgressBar = $BottomLeft/HBox/VBox/StaminaBar
@onready var _weight_bar: ProgressBar = $BottomLeft/HBox/VBox/WeightBar
@onready var _status_effects_box: HBoxContainer = $BottomLeft/HBox/VBox/StatusEffects

@onready var _currency_label: Label = $TopRight/VBox/CurrencyLabel
@onready var _glow_label: Label = $TopRight/VBox/GlowLabel

@onready var _quest_panel: Control = $QuestPanel
@onready var _quest_name_label: Label = $QuestPanel/VBox/QuestName
@onready var _quest_progress_label: Label = $QuestPanel/VBox/QuestProgress
@onready var _extract_label: Label = $ExtractLabel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _local_player: Player = null
var _status_effects: Dictionary = {} # effect_id -> { "node": Control, "time_left": float }

var _tool_dock: MarginContainer
var _tool_slot_panels: Array[PanelContainer] = []
var _active_tool_index: int = 0

const TOOL_SLOTS: Array[Dictionary] = [
	{"key": "1", "icon": "⛏", "name": "Pickaxe"},
	{"key": "2", "icon": "🪓", "name": "Axe"},
	{"key": "3", "icon": "🗡", "name": "Spear"},
	{"key": "4", "icon": "🪵", "name": "Club"},
	{"key": "5", "icon": "🔥", "name": "Torch"},
]

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_setup_bar_styles()
	_setup_tool_dock()
	_extract_label.visible = false

	# Currency connection
	ProgressionManager.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(ProgressionManager.currency)

	# Wait for local player to spawn
	await get_tree().process_frame
	_connect_to_local_player()
	_connect_quest_manager()

func _process(delta: float) -> void:
	# Tick down status effects
	var expired: Array[String] = []
	for id: String in _status_effects:
		var data: Dictionary = _status_effects[id]
		data["time_left"] -= delta
		var label: Label = data["node"].get_node_or_null("TimeLabel")
		if label:
			label.text = "%.0fs" % ceilf(data["time_left"])
		if data["time_left"] <= 0:
			expired.append(id)

	for id in expired:
		remove_status_effect(id)

# ---------------------------------------------------------------------------
# Bar Styling
# ---------------------------------------------------------------------------
func _setup_bar_styles() -> void:
	# Health: Deep red bg, vibrant crimson fill
	_apply_bar_style(_health_bar, Color(0.25, 0.08, 0.08, 0.85), Color(0.92, 0.25, 0.22, 1.0))

	# Stamina: Dark forest bg, bright lime fill
	_apply_bar_style(_stamina_bar, Color(0.08, 0.22, 0.10, 0.85), Color(0.25, 0.88, 0.45, 1.0))

	# Weight: Dark amber bg, warm gold fill
	_apply_bar_style(_weight_bar, Color(0.25, 0.18, 0.06, 0.85), Color(0.95, 0.72, 0.20, 1.0))

func _apply_bar_style(bar: ProgressBar, bg_col: Color, fill_col: Color) -> void:
	if not bar:
		return
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_col
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_col
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill_style)

# ---------------------------------------------------------------------------
# Player Connections
# ---------------------------------------------------------------------------
func _connect_to_local_player() -> void:
	_local_player = GameManager.get_local_player() as Player
	if not _local_player:
		await get_tree().create_timer(0.3).timeout
		_connect_to_local_player()
		return

	_local_player.health_changed.connect(_on_health_changed)
	_local_player.stamina_changed.connect(_on_stamina_changed)
	_local_player.ragdoll_state_changed.connect(_on_ragdoll_state_changed)

	var inv := _local_player.inventory
	if inv:
		inv.weight_changed.connect(_on_weight_changed)

	var glow := _local_player.glow_system
	if glow:
		glow.rock_count_changed.connect(_on_glow_changed)

	var vm := _local_player.find_child("FirstPersonViewmodel", true, false) as FirstPersonViewmodel
	if vm:
		vm.active_tool_changed.connect(_on_active_tool_changed)
		_on_active_tool_changed(int(vm.current_tool), vm.get_current_tool_name())

	_on_health_changed(_local_player.current_health, _local_player.max_health)
	_on_stamina_changed(_local_player.current_stamina, _local_player.max_stamina)

func _connect_quest_manager() -> void:
	QuestManager.quest_accepted.connect(_on_quest_accepted)
	QuestManager.quest_progress_updated.connect(_on_quest_progress)
	QuestManager.quest_completed.connect(_on_quest_completed)
	if QuestManager.active_quest:
		_on_quest_accepted(QuestManager.active_quest)

# ---------------------------------------------------------------------------
# Status Effects System
# ---------------------------------------------------------------------------
func add_status_effect(effect_id: String, display_name: String, icon_emoji: String, duration: float) -> void:
	if _status_effects.has(effect_id):
		_status_effects[effect_id]["time_left"] = duration
		return

	var badge := PanelContainer.new()
	badge.name = "Effect_" + effect_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.85)
	style.border_color = Color(0.85, 0.65, 0.25, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	badge.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.theme_override_constants.separation = 4

	var icon := Label.new()
	icon.text = icon_emoji
	icon.theme_override_font_sizes.font_size = 14
	hbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.theme_override_font_sizes.font_size = 12
	name_lbl.theme_override_colors.font_color = Color(0.9, 0.85, 0.75, 1)
	hbox.add_child(name_lbl)

	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	time_lbl.text = "%.0fs" % ceilf(duration)
	time_lbl.theme_override_font_sizes.font_size = 11
	time_lbl.theme_override_colors.font_color = Color(0.95, 0.75, 0.35, 1)
	hbox.add_child(time_lbl)

	badge.add_child(hbox)
	_status_effects_box.add_child(badge)

	_status_effects[effect_id] = {
		"node": badge,
		"time_left": duration
	}

func remove_status_effect(effect_id: String) -> void:
	if not _status_effects.has(effect_id):
		return
	var data: Dictionary = _status_effects[effect_id]
	if is_instance_valid(data["node"]):
		data["node"].queue_free()
	_status_effects.erase(effect_id)

func _on_ragdoll_state_changed(is_ragdolling: bool) -> void:
	if is_ragdolling:
		add_status_effect("ragdoll", "KNOCKED DOWN (Press I)", "💫", 999.0)
	else:
		remove_status_effect("ragdoll")

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------
func _on_health_changed(current: float, maximum: float) -> void:
	if _health_bar:
		_health_bar.max_value = maximum
		_health_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	if _stamina_bar:
		_stamina_bar.max_value = maximum
		_stamina_bar.value = current

func _on_weight_changed(current: float, maximum: float) -> void:
	if _weight_bar:
		_weight_bar.max_value = maximum
		_weight_bar.value = current

func _on_currency_changed(amount: int) -> void:
	if _currency_label:
		_currency_label.text = "🛞 %d STONE RINGS" % amount

func _on_glow_changed(current: int, maximum: int) -> void:
	if _glow_label:
		_glow_label.text = "🪨 %d / %d GLOW ROCKS" % [current, maximum]

func _on_quest_accepted(quest: QuestDefinition) -> void:
	if not quest:
		_quest_panel.visible = false
		return
	_quest_panel.visible = true
	_quest_name_label.text = quest.quest_name
	_quest_progress_label.text = "0 / %d" % quest.required_quantity

func _on_quest_progress(_quest: QuestDefinition, current: int, required: int) -> void:
	if _quest_progress_label:
		_quest_progress_label.text = "%d / %d" % [current, required]

func _on_quest_completed(_quest: QuestDefinition) -> void:
	if _quest_name_label:
		_quest_name_label.text = "QUEST COMPLETE!"
	if _quest_progress_label:
		_quest_progress_label.text = "Head to extraction!"
	var tween := create_tween().set_loops(3)
	tween.tween_property(_quest_panel, "modulate:a", 0.3, 0.25)
	tween.tween_property(_quest_panel, "modulate:a", 1.0, 0.25)

func show_extraction_countdown(time_left: float, _total: float) -> void:
	if _extract_label:
		_extract_label.visible = true
		_extract_label.text = "EXTRACTING IN %.0f…" % ceilf(time_left)

# ---------------------------------------------------------------------------
# Tool Dock Quickslot HUD
# ---------------------------------------------------------------------------
func _setup_tool_dock() -> void:
	_tool_dock = MarginContainer.new()
	_tool_dock.name = "ToolDockContainer"
	_tool_dock.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_tool_dock.anchor_left = 0.5
	_tool_dock.anchor_right = 0.5
	_tool_dock.anchor_top = 1.0
	_tool_dock.anchor_bottom = 1.0
	_tool_dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tool_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tool_dock.offset_left = -225.0
	_tool_dock.offset_right = 225.0
	_tool_dock.offset_top = -65.0
	_tool_dock.offset_bottom = -15.0

	var hbox := HBoxContainer.new()
	hbox.name = "SlotsHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	_tool_dock.add_child(hbox)

	_tool_slot_panels.clear()
	for i in TOOL_SLOTS.size():
		var slot_data: Dictionary = TOOL_SLOTS[i]
		var panel := PanelContainer.new()
		panel.name = "Slot_%d" % (i + 1)
		panel.custom_minimum_size = Vector2(82, 44)

		var inner_vbox := VBoxContainer.new()
		inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		inner_vbox.add_theme_constant_override("separation", 1)

		var top_hbox := HBoxContainer.new()
		top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		top_hbox.add_theme_constant_override("separation", 4)

		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % slot_data["key"]
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35, 0.8))
		top_hbox.add_child(key_lbl)

		var icon_lbl := Label.new()
		icon_lbl.text = slot_data["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 13)
		top_hbox.add_child(icon_lbl)
		inner_vbox.add_child(top_hbox)

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.text = slot_data["name"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner_vbox.add_child(name_lbl)

		panel.add_child(inner_vbox)
		hbox.add_child(panel)
		_tool_slot_panels.append(panel)

	add_child(_tool_dock)
	_update_tool_dock_styles()

func _update_tool_dock_styles() -> void:
	for i in _tool_slot_panels.size():
		var panel: PanelContainer = _tool_slot_panels[i]
		var is_active := (i == _active_tool_index)
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6

		var name_lbl: Label = panel.find_child("NameLabel", true, false) as Label

		if is_active:
			style.bg_color = Color(0.24, 0.16, 0.08, 0.95)
			style.border_color = Color(1.0, 0.78, 0.32, 1.0)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			if name_lbl:
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
		else:
			style.bg_color = Color(0.10, 0.09, 0.08, 0.75)
			style.border_color = Color(0.32, 0.26, 0.20, 0.6)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			if name_lbl:
				name_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.52, 1.0))

		panel.add_theme_stylebox_override("panel", style)


func _on_active_tool_changed(tool_idx: int, _tool_name: String) -> void:
	_active_tool_index = tool_idx
	_update_tool_dock_styles()

