## PlayerInventory.gd
## Tracks items carried by a single player during an expedition.
## Attached as a child Node on the Player scene.

class_name PlayerInventory
extends Node

signal item_added(item_id: String, quantity: int, new_total: int)
signal item_removed(item_id: String, quantity: int, new_total: int)
signal inventory_changed()
signal weight_changed(current: float, maximum: float)

@export var max_carry_weight: float = 30.0

## item_id -> quantity
var items: Dictionary = {}
var current_weight: float = 0.0

## Cached item definitions: item_id -> ItemDefinition
var _defs: Dictionary = {}

func _ready() -> void:
	_load_item_definitions()

func _load_item_definitions() -> void:
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

## Add items. Returns true if at least some were added.
func add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var w := _item_weight(item_id)
	var max_addable := floori((max_carry_weight - current_weight) / w) if w > 0.0 else quantity
	var to_add := mini(quantity, max_addable)
	if to_add <= 0:
		return false
	items[item_id] = items.get(item_id, 0) + to_add
	current_weight += w * to_add
	item_added.emit(item_id, to_add, items[item_id])
	inventory_changed.emit()
	weight_changed.emit(current_weight, max_carry_weight)
	return true

## Remove items. Returns true if successful.
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if not has_item(item_id, quantity):
		return false
	var w := _item_weight(item_id)
	items[item_id] -= quantity
	current_weight = maxf(0.0, current_weight - w * quantity)
	var new_total: int = items[item_id]
	if new_total <= 0:
		items.erase(item_id)
	item_removed.emit(item_id, quantity, new_total)
	inventory_changed.emit()
	weight_changed.emit(current_weight, max_carry_weight)
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return items.get(item_id, 0) >= quantity

func get_quantity(item_id: String) -> int:
	return items.get(item_id, 0)

func get_all_items() -> Dictionary:
	return items.duplicate()

func is_full() -> bool:
	return current_weight >= max_carry_weight

func clear() -> void:
	items.clear()
	current_weight = 0.0
	inventory_changed.emit()
	weight_changed.emit(0.0, max_carry_weight)

func _item_weight(item_id: String) -> float:
	var def := _defs.get(item_id) as ItemDefinition
	return def.weight if def else 1.0
