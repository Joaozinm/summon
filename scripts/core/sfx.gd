extends Node
## Procedural SFX (autoload "Sfx"). Everything is synthesized into one AudioStreamGenerator —
## no external audio files. On Web the player must use Stream playback: the default Sample
## mode does not support procedural generation (Godot 4.7 docs, "Exporting for the Web").

const RATE := 22050.0
const MAX_VOICES := 24

enum Wave { SINE, SQUARE, TRI, NOISE }

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


## Named presets used by the game.
func play(sound: StringName) -> void:
	match sound:
		&"golpe":  # swing
			_voice(Wave.NOISE, 1400.0, 500.0, 0.09, 0.20, 0.0, 0.35)
		&"disparo":
			_voice(Wave.NOISE, 2600.0, 1200.0, 0.07, 0.14, 0.0, 0.5)
			_voice(Wave.TRI, 900.0, 500.0, 0.06, 0.08)
		&"impacto":
			_voice(Wave.SINE, 170.0, 60.0, 0.12, 0.45)
			_voice(Wave.NOISE, 900.0, 300.0, 0.05, 0.22, 0.0, 0.25)
		&"impacto_pesado":
			_voice(Wave.SINE, 120.0, 38.0, 0.28, 0.65)
			_voice(Wave.NOISE, 600.0, 150.0, 0.12, 0.35, 0.0, 0.2)
		&"morte":
			_voice(Wave.SQUARE, 320.0, 70.0, 0.45, 0.16)
			_voice(Wave.NOISE, 500.0, 100.0, 0.30, 0.18, 0.0, 0.15)
		&"cura":
			_voice(Wave.SINE, 660.0, 990.0, 0.25, 0.18)
		&"foco":
			_voice(Wave.SQUARE, 440.0, 440.0, 0.08, 0.10)
			_voice(Wave.SQUARE, 660.0, 660.0, 0.10, 0.10, 0.08)
		&"sino":  # summoning bell: inharmonic partials, long decay
			for p: Array in [[880.0, 0.30], [1320.0, 0.16], [2210.0, 0.10], [3050.0, 0.05]]:
				_voice(Wave.SINE, p[0], p[0], 1.3, p[1])
		&"vitoria":
			var notes := [523.25, 659.25, 783.99, 1046.5]
			for i in notes.size():
				_voice(Wave.TRI, notes[i], notes[i], 0.5 if i < 3 else 0.9, 0.28, i * 0.13)
		&"derrota":
			var notes := [392.0, 329.63, 261.63]
			for i in notes.size():
				_voice(Wave.TRI, notes[i], notes[i] * 0.97, 0.6, 0.25, i * 0.22)


func _voice(wave: Wave, f0: float, f1: float, dur: float, vol: float,
		delay := 0.0, lowpass := 1.0) -> void:
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	_voices.append({
		"wave": wave, "f0": f0, "f1": f1, "dur": dur, "vol": vol,
		"t": -delay, "phase": 0.0, "lp": lowpass, "z": 0.0,
	})


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	if _voices.is_empty():
		buf.fill(Vector2.ZERO)
		_playback.push_buffer(buf)
		return
	var dt := 1.0 / RATE
	for i in n:
		var s := 0.0
		for v: Dictionary in _voices:
			var t: float = v.t
			v.t = t + dt
			if t < 0.0:
				continue
			var dur: float = v.dur
			if t > dur:
				continue
			var k := t / dur
			var f: float = v.f0 * pow(v.f1 / v.f0, k)
			var ph: float = v.phase + f * dt
			ph -= floorf(ph)
			v.phase = ph
			var x := 0.0
			match v.wave:
				Wave.SINE:
					x = sin(ph * TAU)
				Wave.SQUARE:
					x = 1.0 if ph < 0.5 else -1.0
				Wave.TRI:
					x = 4.0 * absf(ph - 0.5) - 1.0
				Wave.NOISE:
					var z: float = v.z + (randf() * 2.0 - 1.0 - v.z) * float(v.lp)
					v.z = z
					x = z
			var env := minf(t / 0.004, 1.0) * pow(1.0 - k, 2.0)
			s += x * env * float(v.vol)
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	_playback.push_buffer(buf)
	_voices = _voices.filter(func(v: Dictionary) -> bool: return float(v.t) <= float(v.dur))
