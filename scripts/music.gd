extends AudioStreamPlayer
## Procedural synthwave loop: drums, bass, pad and an arpeggio in the second half.
## Rendered once in small chunks across frames (no freeze on start), then looped.
## Plays on its own "Music" bus, which has a low-pass filter for the "muffled" pit stop feel.

const RATE := 22050
const BPM := 108.0
# Two bars per chord: Am F C G | Am F G E (MIDI notes of each triad).
const CHORDS := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62],
	[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]]
const BASS_STEPS := [0, 0, 12, 0, 0, 12, 0, 7]  # 8th notes, semitones above the root
const ARP_STEPS := [0, 1, 2, 1]  # chord tone index per 16th note

var _buf := PackedFloat32Array()
var _bus_idx := -1
var _muted := false
var _volume := 0.8


func _ready() -> void:
	# The web build plays audio as Web Audio samples, where runtime buses and bus
	# effects are unreliable; there the music stays on Master without the muffle effect.
	if not OS.has_feature("web"):
		_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_bus_idx)
		AudioServer.set_bus_name(_bus_idx, "Music")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 650.0
		AudioServer.add_bus_effect(_bus_idx, lp)
		AudioServer.set_bus_effect_enabled(_bus_idx, 0, false)
		bus = "Music"
	_apply()
	_render()


func set_muffled(on: bool) -> void:
	if _bus_idx >= 0:
		AudioServer.set_bus_effect_enabled(_bus_idx, 0, on)


func set_volume(v: float) -> void:
	_volume = v
	_apply()


## Music on/off only pauses this player, so sound effects are never affected.
func set_muted(on: bool) -> void:
	_muted = on
	_apply()


func _apply() -> void:
	volume_db = -80.0 if _muted else -10.0 + linear_to_db(maxf(_volume, 0.0001))
	stream_paused = _muted


static func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func _render() -> void:
	var beat := 60.0 / BPM
	var bars := CHORDS.size() * 2
	var n := int(bars * 4 * beat * RATE)
	_buf.resize(n)
	_buf.fill(0.0)
	for bar in bars:
		var chord: Array = CHORDS[bar / 2]
		var t0 := bar * 4 * beat
		for note in chord:
			_pad(t0, 4 * beat, _freq(note))
		await get_tree().process_frame
		for b in 4:
			var tb := t0 + b * beat
			if b % 2 == 0:
				_kick(tb)
			else:
				_snare(tb)
			_hat(tb, 0.03)
			_hat(tb + beat / 2, 0.05)
		for e in 8:
			_bass(t0 + e * beat / 2, _freq(chord[0] - 24 + BASS_STEPS[e]))
		if bar >= CHORDS.size():
			for s in 16:
				_arp(t0 + s * beat / 4, _freq(chord[ARP_STEPS[s % 4]] + 12 + (12 if s % 8 == 7 else 0)))
		await get_tree().process_frame
	var peak := 0.001
	for v in _buf:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(_buf[i] * gain, -1.0, 1.0) * 32000.0))
		if i % 100000 == 0:
			await get_tree().process_frame
	_buf = PackedFloat32Array()
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	stream = s
	play()
	stream_paused = _muted


# Each voice adds into _buf; indices wrap so note tails continue at the loop start.

func _pad(t0: float, dur: float, f: float) -> void:
	var i0 := int(t0 * RATE)
	var n := _buf.size()
	var ph1 := 0.0
	var ph2 := 0.0
	for k in int((dur + 0.4) * RATE):
		var t := float(k) / RATE
		ph1 = fmod(ph1 + f / RATE, 1.0)
		ph2 = fmod(ph2 + f * 1.004 / RATE, 1.0)
		var env := minf(t / 0.2, 1.0) * (1.0 if t < dur else exp(-(t - dur) * 8.0))
		var v := (absf(ph1 - 0.5) + absf(ph2 - 0.5)) * 2.0 - 1.0
		_buf[(i0 + k) % n] += v * env * 0.05


func _bass(t0: float, f: float) -> void:
	var i0 := int(t0 * RATE)
	var n := _buf.size()
	var ph := 0.0
	var y := 0.0
	for k in int(0.3 * RATE):
		var t := float(k) / RATE
		ph = fmod(ph + f / RATE, 1.0)
		y += 0.12 * ((ph * 2.0 - 1.0) - y)
		_buf[(i0 + k) % n] += y * exp(-t * 6.0) * 0.32


func _arp(t0: float, f: float) -> void:
	var i0 := int(t0 * RATE)
	var n := _buf.size()
	var ph := 0.0
	for k in int(0.16 * RATE):
		var t := float(k) / RATE
		ph = fmod(ph + f / RATE, 1.0)
		_buf[(i0 + k) % n] += (0.5 if ph < 0.5 else -0.5) * exp(-t * 16.0) * 0.07


func _kick(t0: float) -> void:
	var i0 := int(t0 * RATE)
	var n := _buf.size()
	var ph := 0.0
	for k in int(0.3 * RATE):
		var t := float(k) / RATE
		ph += (45.0 + 90.0 * exp(-t * 30.0)) / RATE
		_buf[(i0 + k) % n] += sin(TAU * ph) * exp(-t * 9.0) * 0.5


func _snare(t0: float) -> void:
	var i0 := int(t0 * RATE)
	var n := _buf.size()
	for k in int(0.2 * RATE):
		var t := float(k) / RATE
		_buf[(i0 + k) % n] += ((randf() * 2.0 - 1.0) * exp(-t * 20.0) * 0.6 + sin(TAU * 190.0 * t) * exp(-t * 25.0) * 0.4) * 0.22


func _hat(t0: float, amp: float) -> void:
	var i0 := int(t0 * RATE)
	var n := _buf.size()
	var prev := 0.0
	for k in int(0.05 * RATE):
		var x := randf() * 2.0 - 1.0
		_buf[(i0 + k) % n] += (x - prev) * exp(-float(k) / RATE * 70.0) * amp
		prev = x
