## MainMenu.gd
## Main menu controller with 3D character preview, live customization swatches,
## and complete multiplayer hosting/joining logic.

extends Control

# ---------------------------------------------------------------------------
# Node References
# ---------------------------------------------------------------------------
@onready var _preview: CharacterPreview = $CharacterPreview if has_node("CharacterPreview") else get_node_or_null("HSplit/LeftPanel/CharacterPreview")
@onready var _title_label: Label = $HSplit/RightPanel/MarginContainer/VBox/TitleBox/TitleLabel

@onready var _main_panel: VBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/MainPanel
@onready var _mp_panel: VBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/MultiplayerPanel
@onready var _cust_panel: VBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/CustomizePanel

@onready var _ip_input: LineEdit = $HSplit/RightPanel/MarginContainer/VBox/MultiplayerPanel/HBox/IPInput
@onready var _status_label: Label = $HSplit/RightPanel/MarginContainer/VBox/StatusLabel

# Swatch containers
@onready var _skin_swatches: HBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/CustomizePanel/SkinSwatches
@onready var _hair_swatches: HBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/CustomizePanel/HairSwatches
@onready var _clothing_swatches: HBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/CustomizePanel/ClothingSwatches
@onready var _accent_swatches: HBoxContainer = $HSplit/RightPanel/MarginContainer/VBox/CustomizePanel/AccentSwatches

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var customization: CharacterCustomizationData

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	if NetworkManager.is_connected_to_session():
		NetworkManager.disconnect_from_game()

	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	_animate_title()

	# Panels initial visibility
	_main_panel.visible = true
	_mp_panel.visible = false
	_cust_panel.visible = false
	_status_label.text = ""

	# Load customization & setup preview
	customization = CharacterCustomizationData.load_or_create()
	if _preview:
		_preview.update_customization(customization)

	_populate_all_swatches()

func _animate_title() -> void:
	if not _title_label:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_title_label, "modulate:a", 0.75, 1.2)
	tween.tween_property(_title_label, "modulate:a", 1.0, 1.2)

# ---------------------------------------------------------------------------
# Swatch System
# ---------------------------------------------------------------------------
func _populate_all_swatches() -> void:
	_create_swatch_buttons(_skin_swatches, CharacterCustomizationData.SKIN_PALETTE, "skin_color")
	_create_swatch_buttons(_hair_swatches, CharacterCustomizationData.HAIR_PALETTE, "hair_color")
	_create_swatch_buttons(_clothing_swatches, CharacterCustomizationData.CLOTHING_PALETTE, "clothing_color")
	_create_swatch_buttons(_accent_swatches, CharacterCustomizationData.ACCENT_PALETTE, "accent_color")
	_update_swatch_highlights()

func _create_swatch_buttons(container: HBoxContainer, palette: Array[Color], property_name: String) -> void:
	for child in container.get_children():
		child.queue_free()

	for color in palette:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = "Apply color"

		# Custom style for the color swatch button
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.2, 0.2, 0.8)
		btn.add_theme_stylebox_override("normal", style)

		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.border_color = Color(1, 1, 1, 0.9)
		hover_style.border_width_left = 3
		hover_style.border_width_right = 3
		hover_style.border_width_top = 3
		hover_style.border_width_bottom = 3
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(func():
			_on_color_swatch_selected(property_name, color)
		)
		container.add_child(btn)

func _on_color_swatch_selected(property_name: String, color: Color) -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	customization.set(property_name, color)
	customization.save_to_file()
	if _preview:
		_preview.update_customization(customization)
	_update_swatch_highlights()

func _update_swatch_highlights() -> void:
	_highlight_swatch_row(_skin_swatches, customization.skin_color)
	_highlight_swatch_row(_hair_swatches, customization.hair_color)
	_highlight_swatch_row(_clothing_swatches, customization.clothing_color)
	_highlight_swatch_row(_accent_swatches, customization.accent_color)

func _highlight_swatch_row(container: HBoxContainer, current_color: Color) -> void:
	for child in container.get_children():
		if child is Button:
			var normal_style: StyleBoxFlat = child.get_theme_stylebox("normal")
			if normal_style:
				var is_match := normal_style.bg_color.is_equal_approx(current_color)
				normal_style.border_color = Color(1.0, 0.85, 0.3, 1.0) if is_match else Color(0.2, 0.2, 0.2, 0.8)
				normal_style.border_width_left = 3 if is_match else 2
				normal_style.border_width_right = 3 if is_match else 2
				normal_style.border_width_top = 3 if is_match else 2
				normal_style.border_width_bottom = 3 if is_match else 2

# ---------------------------------------------------------------------------
# Navigation Buttons
# ---------------------------------------------------------------------------
func _on_play_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	_main_panel.visible = false
	_mp_panel.visible = true
	_status_label.text = ""

func _on_customize_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	_main_panel.visible = false
	_cust_panel.visible = true
	_status_label.text = ""

func _on_randomize_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	customization.skin_color = CharacterCustomizationData.SKIN_PALETTE.pick_random()
	customization.hair_color = CharacterCustomizationData.HAIR_PALETTE.pick_random()
	customization.clothing_color = CharacterCustomizationData.CLOTHING_PALETTE.pick_random()
	customization.accent_color = CharacterCustomizationData.ACCENT_PALETTE.pick_random()
	customization.save_to_file()
	if _preview:
		_preview.update_customization(customization)
	_update_swatch_highlights()

func _on_reset_customization_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	customization = CharacterCustomizationData.get_default()
	customization.save_to_file()
	if _preview:
		_preview.update_customization(customization)
	_update_swatch_highlights()

func _on_back_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	_mp_panel.visible = false
	_cust_panel.visible = false
	_main_panel.visible = true
	_status_label.text = ""

func _on_debug_island_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	GameManager.enter_debug_island()

func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	get_tree().quit()

# ---------------------------------------------------------------------------
# Multiplayer Callbacks
# ---------------------------------------------------------------------------
func _on_host_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	_status_label.text = "Starting expedition server…"
	var err := NetworkManager.host_game()
	if err != OK:
		_status_label.text = "Failed to host: %s" % error_string(err)
		return
	_status_label.text = "Hosting expedition! Entering Tribe Camp…"
	await get_tree().create_timer(0.4).timeout
	GameManager.enter_camp()

func _on_join_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	var addr := _ip_input.text.strip_edges()
	if addr.is_empty():
		addr = "127.0.0.1"
	_status_label.text = "Connecting to %s…" % addr
	NetworkManager.join_game(addr)

func _on_connected() -> void:
	_status_label.text = "Connected! Joining Tribe Camp…"
	await get_tree().create_timer(0.3).timeout
	GameManager.enter_camp()

func _on_connection_failed() -> void:
	_status_label.text = "Connection failed. Check host IP address."

func _on_server_disconnected() -> void:
	_status_label.text = "Server disconnected."
	_mp_panel.visible = false
	_main_panel.visible = true
