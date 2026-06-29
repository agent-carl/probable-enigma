class_name Synth
extends RefCounted
## Процедурный синтез аудио для GUNFALL: тоны, шум и зацикленная музыка.
## Чистые статические функции (без состояния) — легко тестируются отдельно.

const RATE := 22050

static func make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

static func tone(f0: float, f1: float, dur: float, type: String, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var f: float = f0 * pow(max(1.0, f1) / f0, t)
		phase += TAU * f / RATE
		var s := 0.0
		match type:
			"square": s = 1.0 if sin(phase) >= 0 else -1.0
			"saw": s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"triangle": s = asin(sin(phase)) * (2.0 / PI)
			_: s = sin(phase)
		var env := (1.0 - t)
		samples[i] = s * env * vol
	return make_wav(samples)

static func noise(dur: float, vol: float, low: bool) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var v := 0.0
	var nr := RandomNumberGenerator.new()
	nr.seed = 1234
	for i in range(n):
		var w := nr.randf() * 2.0 - 1.0
		if low:
			v = v * 0.92 + w * 0.08
		else:
			v = w
		var t := float(i) / n
		samples[i] = v * (1.0 - t) * vol
	return make_wav(samples)

static func build_music(theme_idx: int, intense: bool) -> AudioStreamWAV:
	# зацикленная тема: бас (треугольник) + арпеджио (синус-пелл) по пентатонике
	var beat := 0.22 if intense else 0.30
	var beats := 16
	var bn := int(beat * RATE)
	var n := beats * bn
	var samples := PackedFloat32Array()
	samples.resize(n)
	var roots := [220.0, 196.0, 174.61, 233.08, 207.65, 246.94, 164.81]
	var root: float = roots[theme_idx % roots.size()]
	var penta := [0, 3, 5, 7, 10, 12]
	var prog := [0, -2, -4, 3]  # смена аккорда каждые 4 доли
	var mr := RandomNumberGenerator.new()
	mr.seed = 1000 + theme_idx * 7 + (1 if intense else 0)
	var bphase := 0.0
	for b in range(beats):
		var chord: int = prog[int(b / 4.0) % prog.size()]
		var deg: int = penta[mr.randi_range(0, penta.size() - 1)]
		var note_f: float = root * pow(2.0, (chord + deg + 12) / 12.0)
		var bass_f: float = root * 0.5 * pow(2.0, chord / 12.0)
		for j in range(bn):
			var idx := b * bn + j
			var tt := float(j) / bn
			bphase += TAU * bass_f / RATE
			var bass := asin(sin(bphase)) * (2.0 / PI) * 0.07
			var env := exp(-tt * 4.0)
			var arp := sin(TAU * note_f * (float(j) / RATE)) * env * (0.11 if intense else 0.09)
			samples[idx] = clampf(bass + arp, -1.0, 1.0)
	var wav := make_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	return wav
