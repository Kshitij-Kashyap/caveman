## ProgressionManager.gd
## Manages persistent player progression: stored resources, upgrades, regions, currency.
## Autoloaded as ProgressionManager. Saves to user:// JSON file.

extends Node

const SAVE_PATH := "user://cave_raiders_save.json"

signal resources_changed(totals: Dictionary)
signal upgrade_purchased(upgrade_id: String)
signal region_unlocked(region_id: String)
signal currency_changed(new_amount: int)

## Resources stored in the Tribe Camp (item_id -> quantity)
var stored_resources: Dictionary = {}

## Purchased upgrade IDs
var purchased_upgrades: Array[String] = []

## Unlocked region IDs (shallow_caves always unlocked)
var unlocked_regions: Array[String] = ["shallow_caves"]

## Primary currency ("Bones")
var currency: int = 0

## Stats
var quests_completed: int = 0
var expeditions_total: int = 0
var expeditions_survived: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

func deposit_resources(items: Dictionary) -> void:
	for item_id: String in items:
		stored_resources[item_id] = stored_resources.get(item_id, 0) + items[item_id]
	resources_changed.emit(stored_resources.duplicate())
	save_game()

## Returns false if insufficient resources
func spend_resources(cost: Dictionary) -> bool:
	for item_id: String in cost:
		if stored_resources.get(item_id, 0) < cost[item_id]:
			return false
	for item_id: String in cost:
		stored_resources[item_id] -= cost[item_id]
		if stored_resources[item_id] <= 0:
			stored_resources.erase(item_id)
	resources_changed.emit(stored_resources.duplicate())
	return true

# ---------------------------------------------------------------------------
# Upgrades
# ---------------------------------------------------------------------------

func purchase_upgrade(upgrade_def: UpgradeDefinition) -> bool:
	if upgrade_def.upgrade_id in purchased_upgrades:
		return false
	for prereq: String in upgrade_def.prerequisites:
		if not prereq in purchased_upgrades:
			return false
	if not spend_resources(upgrade_def.cost_resources):
		return false
	purchased_upgrades.append(upgrade_def.upgrade_id)
	upgrade_purchased.emit(upgrade_def.upgrade_id)
	save_game()
	return true

func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in purchased_upgrades

## Sum effect_value of all purchased upgrades that match the given effect type
func get_upgrade_bonus(effect_type: UpgradeDefinition.EffectType) -> float:
	## TODO: cache loaded UpgradeDefinition resources for performance
	return 0.0

# ---------------------------------------------------------------------------
# Regions + Currency
# ---------------------------------------------------------------------------

func unlock_region(region_id: String) -> void:
	if not region_id in unlocked_regions:
		unlocked_regions.append(region_id)
		region_unlocked.emit(region_id)
		save_game()

func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)

func spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	currency_changed.emit(currency)
	return true

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

func record_expedition(survived: bool) -> void:
	expeditions_total += 1
	if survived:
		expeditions_survived += 1
	save_game()

func record_quest_completed() -> void:
	quests_completed += 1
	save_game()

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func save_game() -> void:
	var data := {
		"stored_resources": stored_resources,
		"purchased_upgrades": purchased_upgrades,
		"unlocked_regions": unlocked_regions,
		"currency": currency,
		"quests_completed": quests_completed,
		"expeditions_total": expeditions_total,
		"expeditions_survived": expeditions_survived,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_error("ProgressionManager: Cannot open save file for writing")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if not result is Dictionary:
		push_error("ProgressionManager: Corrupt save file")
		return
	var d: Dictionary = result
	stored_resources = d.get("stored_resources", {})
	purchased_upgrades = Array(d.get("purchased_upgrades", []), TYPE_STRING, "", null)
	unlocked_regions   = Array(d.get("unlocked_regions", ["shallow_caves"]), TYPE_STRING, "", null)
	currency           = d.get("currency", 0)
	quests_completed   = d.get("quests_completed", 0)
	expeditions_total  = d.get("expeditions_total", 0)
	expeditions_survived = d.get("expeditions_survived", 0)

func reset_save() -> void:
	stored_resources = {}
	purchased_upgrades = []
	unlocked_regions = ["shallow_caves"]
	currency = 0
	quests_completed = 0
	expeditions_total = 0
	expeditions_survived = 0
	save_game()
