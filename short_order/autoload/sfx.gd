extends Node
## Plays sound effects and the two loops (grill sizzle and jukebox music).
## Anywhere in the game: Sfx.play("cash"). Sounds live in res://sounds/.
## Every button in the game clicks on its own (see _on_node_added).

const SOUNDS := ["click", "pop", "place", "remove", "cash", "bell", "door", "fanfare", "error",
	"plate_break", "sweep", "good_review", "bad_review", "repair", "day_end", "critic", "inspector"]
const SETTINGS_PATH := "user://settings.cfg"
const MIN_GAP := 0.07            # the same sound won't play again within this many seconds

var streams := {}
var players: Array[AudioStreamPlayer] = []
var last_played := {}
var sizzle: AudioStreamPlayer
var music: AudioStreamPlayer
var sound_on := true
var volume := 0.8                # 0..1
var fullscreen := false

signal settings_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SOUNDS:
		var path := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	sizzle = make_loop("sizzle", -16.0)
	music = make_loop("jukebox", -12.0)
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	get_tree().set_auto_accept_quit(false)   # closing the window goes through quit_game()


func make_loop(n: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := "res://sounds/%s.wav" % n
	if ResourceLoader.exists(path):
		var st: AudioStreamWAV = load(path)
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
		p.stream = st
	p.volume_db = db
	add_child(p)
	return p


## Sounds use their own dice, so playing (or muting) them never changes what
## happens in the game.
var rng := RandomNumberGenerator.new()


func play(n: String, db: float = 0.0, pitch_spread: float = 0.06) -> void:
	if not sound_on or not streams.has(n):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_played.get(n, -10.0) < MIN_GAP:
		return
	last_played[n] = now
	for p in players:
		if not p.playing:
			p.stream = streams[n]
			p.volume_db = db
			p.pitch_scale = 1.0 + rng.randf_range(-pitch_spread, pitch_spread)
			p.play()
			return


## Turns the looping sounds on or off; called by main.gd a few times a second.
func set_loops(cooking: bool, jukebox: bool) -> void:
	_set_loop(sizzle, cooking and sound_on)
	_set_loop(music, jukebox and sound_on)


func _set_loop(p: AudioStreamPlayer, on: bool) -> void:
	if p.stream == null:
		return
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()


func set_sound_on(on: bool) -> void:
	sound_on = on
	if not on:
		for p in players:
			p.stop()
		set_loops(false, false)
	save_settings()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sound_on = cfg.get_value("audio", "sound_on", true)
		volume = cfg.get_value("audio", "volume", 0.8)
		fullscreen = cfg.get_value("display", "fullscreen", false)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func save_settings() -> void:
	settings_changed.emit()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("silent"):
		(n as BaseButton).pressed.connect(func(): play("click", -8.0, 0.02))


## Closes the game after letting any sound that's still playing stop cleanly
## (otherwise Godot complains about leftover sounds when the game exits).
func quit_game() -> void:
	for p in players + [sizzle, music]:
		p.stop()
		p.stream = null
	streams.clear()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
