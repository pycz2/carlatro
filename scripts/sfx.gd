extends Node
## Procedural sound effects, synthesized once at startup. No audio files needed.

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var volume := 1.0  # 0..1, from settings


func _ready() -> void:
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams.click = _gen(0.05, func(t: float, _d: float): return _noise() * 0.3 * exp(-t * 90.0) + sin(TAU * 1800.0 * t) * 0.25 * exp(-t * 60.0))
	_streams.tick = _gen(0.03, func(t: float, _d: float): return sin(TAU * 2400.0 * t) * 0.12 * exp(-t * 120.0))
	_streams.card = _gen(0.09, func(t: float, _d: float): return _noise() * 0.45 * exp(-t * 45.0))
	_streams.chips = _gen(0.16, func(t: float, _d: float): return (sin(TAU * 880.0 * t) + 0.4 * sin(TAU * 1760.0 * t)) * 0.33 * exp(-t * 22.0))
	_streams.mult = _gen(0.2, func(t: float, _d: float): return signf(sin(TAU * 330.0 * t)) * 0.16 * exp(-t * 16.0) + sin(TAU * 165.0 * t) * 0.25 * exp(-t * 12.0))
	_streams.xmult = _gen(0.45, func(t: float, d: float): return _saw(_sweep(t, 90.0, 520.0, d)) * 0.3 * (1.0 - t / d))
	_streams.engine = _gen(0.8, func(t: float, d: float):
		var ph := _sweep(t, 45.0, 120.0, d)
		var env := minf(t * 12.0, 1.0) * (1.0 - t / d)
		return (_saw(ph) * 0.35 + _saw(ph * 0.5) * 0.25 + _noise() * 0.08) * env * (0.8 + 0.2 * sin(TAU * 28.0 * t)))
	_streams.coin = _gen(0.3, func(t: float, _d: float):
		var f := 988.0 if t < 0.07 else 1319.0
		return sin(TAU * f * t) * 0.3 * exp(-t * 9.0))
	_streams.score = _gen(0.5, func(t: float, _d: float): return (sin(TAU * 1047.0 * t) + 0.6 * sin(TAU * 1568.0 * t) + 0.3 * sin(TAU * 2093.0 * t)) * 0.2 * exp(-t * 7.0))
	_streams.win = _gen(0.75, func(t: float, _d: float):
		var notes := [523.0, 659.0, 784.0, 1047.0, 1319.0]
		var i := mini(int(t / 0.12), notes.size() - 1)
		var lt := t - i * 0.12
		return (sin(TAU * notes[i] * t) * 0.3 + _saw(notes[i] * t) * 0.06) * exp(-lt * 6.0))
	_streams.lose = _gen(1.0, func(t: float, d: float): return _saw(_sweep(t, 300.0, 60.0, d)) * 0.25 * (1.0 - t / d))
	_streams.error = _gen(0.18, func(t: float, _d: float): return signf(sin(TAU * 110.0 * t)) * 0.18 * (1.0 - t / 0.18))
	_streams["break"] = _gen(0.35, func(t: float, _d: float): return (_noise() * 0.4 + sin(TAU * 3100.0 * t) * 0.2) * exp(-t * 11.0))


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if volume <= 0.0:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db + linear_to_db(volume)
	p.play()


static func _noise() -> float:
	return randf() * 2.0 - 1.0


static func _saw(phase: float) -> float:
	return 2.0 * (phase - floorf(phase)) - 1.0


## Phase (in cycles) of a linear frequency sweep from f0 to f1 over d seconds.
static func _sweep(t: float, f0: float, f1: float, d: float) -> float:
	return f0 * t + (f1 - f0) * t * t / (2.0 * d)


func _gen(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = clampf(f.call(float(i) / RATE, dur), -1.0, 1.0)
		if i > n - 64:
			v *= float(n - i) / 64.0
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	return s
