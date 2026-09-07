## Crosshair.gd
## Dynamic first-person reticle and interaction HUD.
## Features:
## - Minimalist prehistoric reticle (center dot + subtle combat pips)
## - Interactive hover prompt pill with action key and target name
## - Hit marker feedback for mining and creature hits

class_name Crosshair
extends Control

# ---------------------------------------------------------------------------
# Node References
# ---------------------------------------------------------------------------
@onready var dot: ColorRect = $CenterContainer/Dot
@onready var ticks: Control = $CenterContainer/Ticks

@onready var prompt_pill: PanelContainer = $CenterContainer/PromptPill
@onready var key_label: Label = $CenterContainer/PromptPill/HBox/KeyLabel
@onready var text_label: Label = $CenterContainer/PromptPill/HBox/TextLabel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _is_targeting: bool = false

func _ready() -> void:
	hide_prompt()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_prompt(action_key: String, description: String, target_type: String = "interact") -> void:
	_is_targeting = true
	key_label.text = "[%s]" % action_key.to_upper()
	text_label.text = description

	# Tint based on target type
	match target_type:
		"mine":
			dot.color = Color(1.0, 0.78, 0.32, 1.0) # Amber
			key_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"creature":
			dot.color = Color(1.0, 0.35, 0.35, 1.0) # Crimson
			key_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		"item":
			dot.color = Color(0.45, 0.95, 0.65, 1.0) # Green
			key_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
		_: # "interact"
			dot.color = Color(0.95, 0.88, 0.75, 1.0) # Bone white
			key_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))

	prompt_pill.visible = true

func hide_prompt() -> void:
	_is_targeting = false
	prompt_pill.visible = false
	dot.color = Color(1.0, 1.0, 1.0, 0.65)

func trigger_hit_marker() -> void:
	var tw := create_tween()
	dot.color = Color(1.0, 0.9, 0.4, 1.0)
	ticks.scale = Vector2(1.5, 1.5)
	tw.parallel().tween_property(dot, "color", Color(1.0, 1.0, 1.0, 0.65), 0.15)
	tw.parallel().tween_property(ticks, "scale", Vector2.ONE, 0.15)
