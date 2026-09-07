## QuestManager.gd
## Tracks active quest progress. Autoloaded as QuestManager.
## Server-authoritative: clients receive progress updates via RPCs.

extends Node

signal quest_accepted(quest: QuestDefinition)
signal quest_progress_updated(quest: QuestDefinition, current: int, required: int)
signal quest_completed(quest: QuestDefinition)

var active_quest: QuestDefinition = null
var _progress: Dictionary = {}   ## target_id -> count

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------------------------------------------------------------------------
# Quest management
# ---------------------------------------------------------------------------

func accept_quest(quest: QuestDefinition) -> void:
	active_quest = quest
	_progress.clear()
	if quest:
		_progress[quest.target_id] = 0
	quest_accepted.emit(quest)

func get_current_progress() -> int:
	if not active_quest:
		return 0
	return _progress.get(active_quest.target_id, 0)

func is_complete() -> bool:
	if not active_quest:
		return false
	return get_current_progress() >= active_quest.required_quantity

# ---------------------------------------------------------------------------
# Event reporters (called by CreatureHealth, LootItem, etc.)
# ---------------------------------------------------------------------------

func report_kill(creature_name: String) -> void:
	if not active_quest:
		return
	if active_quest.quest_type not in [
		QuestDefinition.QuestType.KILL,
		QuestDefinition.QuestType.HUNT,
		QuestDefinition.QuestType.BOSS
	]:
		return
	if active_quest.target_id != creature_name and active_quest.target_id != "any":
		return
	_increment(creature_name)

func report_collect(item_id: String, quantity: int = 1) -> void:
	if not active_quest:
		return
	if active_quest.quest_type != QuestDefinition.QuestType.COLLECT:
		return
	if active_quest.target_id != item_id and active_quest.target_id != "any":
		return
	_increment(item_id, quantity)

func report_find(location_id: String) -> void:
	if not active_quest:
		return
	if active_quest.quest_type != QuestDefinition.QuestType.FIND:
		return
	if active_quest.target_id == location_id:
		_increment(location_id)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _increment(target_id: String, amount: int = 1) -> void:
	_progress[target_id] = _progress.get(target_id, 0) + amount
	var current: int = _progress[target_id]
	quest_progress_updated.emit(active_quest, current, active_quest.required_quantity)
	if current >= active_quest.required_quantity:
		_complete_quest()

func _complete_quest() -> void:
	if not active_quest:
		return
	quest_completed.emit(active_quest)
	## Grant rewards through ProgressionManager
	if not active_quest.reward_resources.is_empty():
		ProgressionManager.deposit_resources(active_quest.reward_resources)
	if active_quest.reward_currency > 0:
		ProgressionManager.add_currency(active_quest.reward_currency)
	ProgressionManager.record_quest_completed()
	active_quest = null
	_progress.clear()
