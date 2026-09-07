## AudioManager.gd
## Central audio manager. Autoloaded as AudioManager.
## Provides named sound hooks throughout the game.
## Assets are not required yet — all calls are safe without streams loaded.

extends Node

enum SFX {
	PICKAXE_HIT,
	PICKAXE_HIT_ORE,
	AXE_HIT_WOOD,
	TREE_FALL,
	TORCH_IGNITE,
	SPEAR_THROW,
	SPEAR_HIT_WALL,
	SPEAR_HIT_FLESH,
	FOOTSTEP_STONE,
	FOOTSTEP_DIRT,
	JUMP,
	LAND,
	GLOW_ROCK_THROW,
	GLOW_ROCK_LAND,
	CREATURE_ALERT,
	CREATURE_ATTACK,
	CREATURE_HURT,
	CREATURE_DIE,
	ITEM_PICKUP,
	ITEM_DROP,
	QUEST_COMPLETE,
	EXTRACTION_START,
	EXTRACTION_COMPLETE,
	UI_CLICK,
	UI_HOVER,
}

enum Music {
	MAIN_MENU,
	CAMP,
	CAVE_AMBIENT,
	BOSS,
}

const SFX_POOL_SIZE := 8

var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []

var _sfx_streams: Dictionary = {}    ## SFX -> AudioStream
var _music_streams: Dictionary = {}  ## Music -> AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	add_child(_ambient_player)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

## Register a loaded AudioStream to a SFX slot
func register_sfx(sfx: SFX, stream: AudioStream) -> void:
	_sfx_streams[sfx] = stream

## Register a loaded AudioStream to a Music slot
func register_music(music: Music, stream: AudioStream) -> void:
	_music_streams[music] = stream

## Play a named sound effect (silent if not loaded)
func play_sfx(sfx: SFX, volume_db: float = 0.0) -> void:
	if not _sfx_streams.has(sfx):
		return
	var player := _get_free_sfx_player()
	if player:
		player.stream = _sfx_streams[sfx]
		player.volume_db = volume_db
		player.play()

## Play music with optional fade-in
func play_music(music: Music, fade_in: float = 1.0) -> void:
	if not _music_streams.has(music):
		return
	_music_player.stream = _music_streams[music]
	_music_player.volume_db = -80.0
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, fade_in)

## Stop current music with optional fade-out
func stop_music(fade_out: float = 1.0) -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(_music_player.stop)

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0] if not _sfx_pool.is_empty() else null
