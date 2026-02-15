# 효과음 — 부드러운 게임 사운드 (프로시저럴)
extends Node

class_name SFX

static func play_drop(tree: SceneTree):
	# 부드러운 "툭" — 짧은 저음
	var samples = _gen_drop()
	_play(tree, samples, 0.4)

static func play_merge(tree: SceneTree, level: int):
	# 기분 좋은 "퐁" + 화음 — 등급별 피치
	var samples = _gen_merge(level)
	_play(tree, samples, 0.5)

static func play_combo(tree: SceneTree, combo: int):
	# 상승 글리산도
	var samples = _gen_combo(combo)
	_play(tree, samples, 0.45)

static func play_countdown_tick(tree: SceneTree, urgency: float):
	# 부드러운 틱
	var samples = _gen_tick(urgency)
	_play(tree, samples, 0.2 + urgency * 0.15)

static func play_countdown_warn(tree: SceneTree):
	var samples = _gen_warn()
	_play(tree, samples, 0.35)

static func play_game_over(tree: SceneTree):
	var samples = _gen_gameover()
	_play(tree, samples, 0.5)

# === 사운드 생성 ===

static func _gen_drop() -> PackedByteArray:
	var sr = 22050
	var dur = 0.12
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)  # 16비트
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 3.0)
		# 피치 다운 (높→낮)
		var freq = 350.0 - t * 1500.0
		var s = sin(t * max(freq, 80) * TAU) * env
		var v = int(clamp(s * 16000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data

static func _gen_merge(level: int) -> PackedByteArray:
	var sr = 22050
	var dur = 0.25
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	var base_freq = 440.0 + level * 60.0
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 2.0)
		# 피치 업 (살짝 상승) + 화음
		var freq = base_freq + t * 200.0
		var s = sin(t * freq * TAU) * 0.5
		s += sin(t * freq * 1.498 * TAU) * 0.3  # 5도 화음
		s += sin(t * freq * 2.0 * TAU) * 0.15    # 옥타브
		s *= env
		var v = int(clamp(s * 14000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data

static func _gen_combo(combo: int) -> PackedByteArray:
	var sr = 22050
	var dur = 0.3
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	var base = 500.0 + combo * 80.0
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 2.5)
		# 빠르게 상승하는 아르페지오
		var note_t = fmod(t * 12.0, 1.0)
		var note_idx = int(t * 12.0) % 4
		var freqs = [base, base * 1.25, base * 1.5, base * 2.0]
		var freq = freqs[note_idx]
		var s = sin(note_t * freq * TAU) * env
		s += sin(note_t * freq * 2.0 * TAU) * 0.2 * env
		var v = int(clamp(s * 12000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data

static func _gen_tick(urgency: float) -> PackedByteArray:
	var sr = 22050
	var dur = 0.05
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	var freq = 800.0 + urgency * 600.0
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 4.0)
		var s = sin(t * freq * TAU) * env * 0.6
		var v = int(clamp(s * 10000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data

static func _gen_warn() -> PackedByteArray:
	var sr = 22050
	var dur = 0.1
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 2.0)
		# 두 음 교대 (경고느낌)
		var freq = 900.0 if fmod(t, 0.04) < 0.02 else 700.0
		var s = sin(t * freq * TAU) * env * 0.7
		var v = int(clamp(s * 12000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data

static func _gen_gameover() -> PackedByteArray:
	var sr = 22050
	var dur = 0.8
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 1.5)
		# 느리게 하강
		var freq = 300.0 - t * 200.0
		var s = sin(t * max(freq, 60) * TAU) * 0.6
		s += sin(t * max(freq * 0.5, 30) * TAU) * 0.3  # 서브베이스
		s *= env
		var v = int(clamp(s * 14000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data

# === 재생 ===

static func _play(tree: SceneTree, data: PackedByteArray, vol: float):
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	audio.stereo = false
	audio.data = data
	
	var player = AudioStreamPlayer.new()
	player.stream = audio
	player.volume_db = linear_to_db(vol)
	tree.root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
