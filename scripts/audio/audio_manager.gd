extends Node
## Audio buses + fully synthesized sound set (no external assets).
## Buses: Master <- SFX (reverb), Master <- Ambience. Master has a compressor.

const RATE := 22050
const POOL_3D := 28
const POOL_2D := 6

var streams: Dictionary = {}
var _pool3d: Array = []
var _pool2d: Array = []
var _i3 := 0
var _i2 := 0
var _volume := {"Master": 0.9, "SFX": 0.9, "Ambience": 0.6}
var _duck_db := 0.0
var _ambience: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_generate_all()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		p.max_db = 6.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool2d.append(p2)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	_ambience.stream = streams["wind"]
	_ambience.volume_db = -5.0
	add_child(_ambience)
	_ambience.play()
	_apply("Master")
	_apply("SFX")
	_apply("Ambience")


func _setup_buses() -> void:
	for bus_name in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.75
	rev.damping = 0.55
	rev.wet = 0.14
	rev.dry = 1.0
	AudioServer.add_bus_effect(sfx, rev)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -9.0
	comp.ratio = 6.0
	comp.gain = 2.0
	AudioServer.add_bus_effect(0, comp)


func _apply(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var lin: float = _volume[bus]
	var db := linear_to_db(maxf(lin, 0.0001))
	if bus == "SFX":
		db += _duck_db
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, lin < 0.01)


func set_volume(bus: String, linear: float) -> void:
	_volume[bus] = clampf(linear, 0.0, 1.0)
	_apply(bus)


func get_volume(bus: String) -> float:
	var v: float = _volume.get(bus, 1.0)
	return v


## Briefly pulls the effects bus down (the "audio drop" before a detonation).
func duck_sfx(depth_db: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_duck, depth_db, 0.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)


func _set_duck(db: float) -> void:
	_duck_db = db
	_apply("SFX")


func play_at(sound: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, unit: float = 25.0) -> void:
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer3D = _pool3d[_i3]
	_i3 = (_i3 + 1) % _pool3d.size()
	p.stop()
	p.stream = streams[sound]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.05, pitch * randf_range(0.94, 1.06))
	p.unit_size = unit
	p.play()


func play_ui(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = _pool2d[_i2]
	_i2 = (_i2 + 1) % _pool2d.size()
	p.stop()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.05, pitch)
	p.play()


## Creates a looping positional emitter parented to `parent` (freed with it).
func make_loop(sound: String, parent: Node3D, vol_db: float = 0.0, unit: float = 20.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = streams.get(sound)
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_db = 6.0
	parent.add_child(p)
	p.play()
	return p


# ---------------------------------------------------------------------------
# Synthesis
# ---------------------------------------------------------------------------

func _generate_all() -> void:
	streams["explosion"] = _make(_gen_explosion(2.8, 75.0, 30.0, 2.2, 1.0))
	streams["impact_big"] = _make(_gen_explosion(5.0, 55.0, 21.0, 1.1, 1.7))
	streams["small_boom"] = _make(_gen_explosion(1.2, 115.0, 45.0, 5.0, 0.3))
	streams["thunder"] = _make(_gen_thunder(3.0))
	streams["zap"] = _make(_gen_zap(0.5))
	streams["cast"] = _make(_gen_cast(0.45))
	streams["fire_loop"] = _make(_gen_fire(2.5), true)
	streams["tornado_loop"] = _make(_gen_wind(3.0, 0.03, 0.14, 1.0), true)
	streams["vortex_loop"] = _make(_gen_vortex(3.0), true)
	streams["implode"] = _make(_gen_implode(1.0))
	streams["whistle"] = _make(_gen_whistle(3.3))
	streams["debris"] = _make(_gen_debris(1.6))
	streams["rumble"] = _make(_gen_rumble(4.0))
	streams["wind"] = _make(_gen_wind(7.0, 0.01, 0.05, 0.6), true)
	streams["chime"] = _make(_gen_chime(1.2))


func _make(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n := buf.size()
	var xf := int(RATE * 0.25)
	if loop:
		# Blend the tail into the head; the loop region then starts after the head.
		for i in xf:
			var t := float(i) / float(xf)
			buf[n - xf + i] = buf[n - xf + i] * (1.0 - t) + buf[i] * t
	var peak := 0.0001
	for i in n:
		var a := absf(buf[i])
		if a > peak:
			peak = a
	var g := 0.95 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = xf
		s.loop_end = n
	return s


func _buffer(dur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE))
	return buf


func _gen_explosion(dur: float, f0: float, f1: float, decay: float, rumble_amt: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(f0, f1, minf(1.0, t * 2.5))
		phase += TAU * f / RATE
		var sub := sin(phase) * exp(-t * decay)
		var w := randf() * 2.0 - 1.0
		var cut := lerpf(0.5, 0.03, minf(1.0, t * 3.0))
		lp += (w - lp) * cut
		lp2 += (w - lp2) * 0.012
		var body := lp * exp(-t * decay * 1.6) * 0.9
		var tail := lp2 * rumble_amt * exp(-t * decay * 0.45) * 3.0
		var click := w * exp(-t * 90.0) * 0.8
		buf[i] = tanh((sub * 1.3 + body + tail + click) * 1.6) * (1.0 - k * k * k)
	return buf


func _gen_thunder(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var lp2 := 0.0
	var m := 1.0
	var m_target := 1.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		if i % 1800 == 0:
			m_target = randf_range(0.25, 1.0)
		m += (m_target - m) * 0.002
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.09
		lp2 += (w - lp2) * 0.015
		var crack := w * exp(-t * 30.0) + lp * exp(-t * 9.0) * 1.5
		var roll := lp2 * m * 5.0 * exp(-t * 1.3) * minf(1.0, t * 6.0 + 0.2)
		buf[i] = tanh(crack * 1.2 + roll) * (1.0 - k * k)
	return buf


func _gen_zap(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var spike := 1.0
	for i in n:
		var t := float(i) / RATE
		if randf() < 0.006:
			spike = 1.0
		spike *= 0.99
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.3
		var hp := w - lp
		var buzz := signf(sin(TAU * 110.0 * t)) * 0.25
		buf[i] = (hp + buzz) * spike * exp(-t * 6.0)
	return buf


func _gen_cast(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var env := sin(PI * k)
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * lerpf(0.02, 0.35, k)
		phase += TAU * lerpf(180.0, 640.0, k * k) / RATE
		buf[i] = (lp * 1.5 + sin(phase) * 0.25) * env
	return buf


func _gen_fire(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var lp2 := 0.0
	var m := 0.7
	var m_target := 0.7
	for i in n:
		if i % 900 == 0:
			m_target = randf_range(0.4, 1.0)
		m += (m_target - m) * 0.003
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.06
		lp2 += (w - lp2) * 0.008
		buf[i] = (lp * 0.7 + lp2 * 4.0) * m
	return buf


func _gen_wind(dur: float, cut_lo: float, cut_hi: float, gust: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var lp2 := 0.0
	var cut := cut_lo
	var cut_target := cut_hi
	for i in n:
		if i % 4000 == 0:
			cut_target = randf_range(cut_lo, cut_hi)
		cut += (cut_target - cut) * 0.0005
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * cut
		lp2 += (lp - lp2) * cut
		buf[i] = lp2 * (1.0 + gust * (cut - cut_lo) / maxf(cut_hi - cut_lo, 0.001))
	return buf


func _gen_vortex(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.02
		var drone := sin(TAU * 48.0 * t) + 0.6 * sin(TAU * 72.5 * t) + 0.4 * sin(TAU * 97.0 * t + 3.0 * sin(TAU * 0.7 * t))
		var trem := 0.7 + 0.3 * sin(TAU * 5.0 * t)
		buf[i] = drone * trem * 0.5 + lp * 2.0
	return buf


func _gen_implode(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		phase += TAU * lerpf(420.0, 18.0, sqrt(k)) / RATE
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * lerpf(0.02, 0.5, k * k)
		buf[i] = (sin(phase) * 0.9 + lp * k * k * 1.2) * k * k
	return buf


func _gen_whistle(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / float(n)
		var f := lerpf(2100.0, 420.0, k) * (1.0 + 0.012 * sin(TAU * 7.0 * t))
		phase += TAU * f / RATE
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * lerpf(0.03, 0.2, k)
		buf[i] = sin(phase) * pow(k, 1.5) * 0.35 + lp * k * k * 2.2
	return buf


func _gen_debris(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var env := 0.0
	var cut := 0.2
	for i in n:
		var k := float(i) / float(n)
		if randf() < 0.0014 * (1.0 - k):
			env = randf_range(0.4, 1.0)
			cut = randf_range(0.08, 0.5)
		env *= 0.996
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * cut
		buf[i] = lp * env
	return buf


func _gen_rumble(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	var lp := 0.0
	var m := 1.0
	var m_target := 1.0
	for i in n:
		var k := float(i) / float(n)
		if i % 2500 == 0:
			m_target = randf_range(0.5, 1.0)
		m += (m_target - m) * 0.001
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.01
		buf[i] = lp * m * sin(PI * minf(1.0, k * 6.0) * 0.5) * (1.0 - k)
	return buf


func _gen_chime(dur: float) -> PackedFloat32Array:
	var buf := _buffer(dur)
	var n := buf.size()
	for i in n:
		var t := float(i) / RATE
		buf[i] = (sin(TAU * 660.0 * t) + 0.6 * sin(TAU * 990.0 * t) + 0.3 * sin(TAU * 1320.0 * t)) * exp(-t * 5.0)
	return buf
