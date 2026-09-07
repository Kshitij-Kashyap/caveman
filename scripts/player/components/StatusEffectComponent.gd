## StatusEffectComponent.gd
## Decoupled component managing active status buffs, debuffs, and knockdown conditions.

class_name StatusEffectComponent
extends Node

signal effect_added(effect_id: String, display_name: String, icon_emoji: String, duration: float)
signal effect_removed(effect_id: String)

var active_effects: Dictionary = {} # effect_id -> { "name": String, "icon": String, "duration": float, "remaining": float }

func _process(delta: float) -> void:
	if active_effects.is_empty():
		return

	var expired: Array[String] = []
	for id: String in active_effects:
		var data: Dictionary = active_effects[id]
		if data.get("duration", 0.0) < 900.0: # Ignore infinite/ragdoll holds
			data["remaining"] -= delta
			if data["remaining"] <= 0.0:
				expired.append(id)

	for id in expired:
		remove_effect(id)

func add_effect(effect_id: String, display_name: String, icon_emoji: String, duration: float) -> void:
	active_effects[effect_id] = {
		"name": display_name,
		"icon": icon_emoji,
		"duration": duration,
		"remaining": duration
	}
	effect_added.emit(effect_id, display_name, icon_emoji, duration)

func remove_effect(effect_id: String) -> void:
	if active_effects.has(effect_id):
		active_effects.erase(effect_id)
		effect_removed.emit(effect_id)

func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id)
