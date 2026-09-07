## ExtractionZone.gd
## Players must all be inside this Area3D for EXTRACTION_TIME seconds to extract.
## Server validates extraction, then calls GameManager to return to camp.

class_name ExtractionZone
extends Area3D

const EXTRACTION_TIME := 5.0

signal extraction_countdown(time_left: float, total: float)
signal extraction_completed()

var _inside: Array[Node3D] = []
var _timer: float = 0.0
var _extracting: bool = false

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	monitoring = true

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not _extracting:
		return
	_timer -= delta
	extraction_countdown.emit(_timer, EXTRACTION_TIME)
	if _timer <= 0.0:
		_do_extract()

func _check_start() -> void:
	if _extracting:
		return
	var player_count := GameManager.get_player_count()
	if player_count <= 0:
		return
	## Count players inside
	var inside_count := 0
	for body in _inside:
		if is_instance_valid(body) and body.has_method("get_multiplayer_authority"):
			inside_count += 1
	if inside_count >= player_count:
		_extracting = true
		_timer = EXTRACTION_TIME
		AudioManager.play_sfx(AudioManager.SFX.EXTRACTION_START)

func _on_enter(body: Node3D) -> void:
	if body.has_method("get_multiplayer_authority"):
		_inside.append(body)
		_check_start()

func _on_exit(body: Node3D) -> void:
	_inside.erase(body)
	if _extracting:
		_extracting = false
		_timer = 0.0

func _do_extract() -> void:
	_extracting = false
	## Deposit all player inventories into storage
	for player in GameManager.get_all_players():
		var inv := player.find_child("PlayerInventory") as PlayerInventory
		if inv:
			ProgressionManager.deposit_resources(inv.get_all_items())
			inv.clear()
	ProgressionManager.record_expedition(true)
	AudioManager.play_sfx(AudioManager.SFX.EXTRACTION_COMPLETE)
	extraction_completed.emit()
	## Return to camp after short delay
	get_tree().create_timer(1.5).timeout.connect(GameManager.return_to_camp)
