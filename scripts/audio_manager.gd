extends Node
## AudioManager (autoload)
## All sound is synthesised in code at start-up, so the game needs no audio files
## (and nothing to download or license). Replace with real files any time:
## put them in res://audio/ and assign them to _sfx["eat"] etc.

const SFX_RATE := 22050
const MUSIC_RATE := 6000

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_ready := false
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep music running while the game is paused
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -11.0
	add_child(_music_player)
	_build_sfx()
	# Music takes a moment to synthesise, so let the first screen appear first.
	await get_tree().process_frame
	_build_music()
	_music_ready = true
	_apply_music_state()


func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if not GameState.sfx_on or not _sfx.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = volume_db
	p.play()


func start_music() -> void:
	_apply_music_state()


func set_music_on(on: bool) -> void:
	GameState.music_on = on
	GameState.save_game()
	_apply_music_state()


func set_sfx_on(on: bool) -> void:
	GameState.sfx_on = on
	GameState.save_game()


func _apply_music_state() -> void:
	if not _music_ready:
		return
	if GameState.music_on:
		if not _music_player.playing:
			_music_player.play()
	else:
		_music_player.stop()


# --- Sound synthesis ---------------------------------------------------------

func _build_sfx() -> void:
	_sfx["click"] = _wav(_tone(700.0, 900.0, 0.06, 0.35))
	_sfx["coin"] = _wav(_seq([987.77, 1318.5], 0.07, 0.35))
	_sfx["swim"] = _wav(_tone(260.0, 170.0, 0.10, 0.25))
	_sfx["eat"] = _wav(_tone(420.0, 880.0, 0.14, 0.5))
	_sfx["hurt"] = _wav(_tone(180.0, 90.0, 0.30, 0.5, true))
	_sfx["grow"] = _wav(_seq([523.25, 659.25, 783.99, 1046.5], 0.09, 0.45))
	_sfx["win"] = _wav(_seq([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5], 0.14, 0.5))
	_sfx["lose"] = _wav(_seq([392.0, 329.63, 261.63, 196.0], 0.22, 0.5))


func _tone(f0: float, f1: float, dur: float, vol: float, square: bool = false) -> PackedFloat32Array:
	var n := int(dur * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t: float = float(i) / float(SFX_RATE)
		var f: float = lerpf(f0, f1, t / dur)
		phase += TAU * f / float(SFX_RATE)
		var env: float = minf(1.0, t / 0.008) * exp(-4.0 * t / dur)
		var s: float = sin(phase)
		if square:
			s = signf(s) * 0.6 + s * 0.4
		out[i] = s * vol * env
	return out


func _seq(freqs: Array, note_len: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for fr in freqs:
		out.append_array(_tone(float(fr), float(fr), note_len, vol))
	return out


func _wav(samples: PackedFloat32Array, rate: int = SFX_RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w


## A calm 8-second looping chord progression (Am - F - C - G) with a soft arpeggio.
func _build_music() -> void:
	var chord_dur := 2.0
	var chords: Array = [
		[110.0, 130.81, 164.81],
		[87.31, 110.0, 130.81],
		[130.81, 164.81, 196.0],
		[98.0, 123.47, 146.83],
	]
	var pattern: Array = [0, 1, 2, 1, 0, 1, 2, 1]
	var per_chord := int(chord_dur * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(per_chord * chords.size())
	for c in chords.size():
		var notes: Array = chords[c]
		for i in per_chord:
			var t: float = float(i) / float(MUSIC_RATE)
			var pad_env: float = sin(PI * t / chord_dur)   # fades to 0 at both ends = no clicks
			var v := 0.0
			for fi in notes:
				var f: float = fi
				v += sin(TAU * f * t) * 0.10 * pad_env
			var step: int = mini(int(t / 0.25), 7)
			var nt: float = fmod(t, 0.25)
			var af: float = float(notes[pattern[step]]) * 2.0
			v += sin(TAU * af * nt) * 0.16 * exp(-7.0 * nt)
			out[c * per_chord + i] = v
	var w := _wav(out, MUSIC_RATE)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = out.size()
	_music_player.stream = w
