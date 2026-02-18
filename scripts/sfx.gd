# 효과음 — 부드러운 게임 사운드 (프로시저럴, 캐싱)
extends Node

class_name SFX

# 캐싱된 AudioStreamWAV
static var _cache: Dictionary = {}
static var _pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
static var _initialized: bool = false

static func init(tree: SceneTree):
	if _initialized:
		return
	_initialized = true
	# 사운드 데이터 캐싱
	_cache["drop"] = _make_stream(_gen_drop())
	_cache["gameover"] = _make_stream(_gen_gameover())
	_cache["warn"] = _make_stream(_gen_warn())
	# 레벨별 merge 캐싱
	for i in range(10):
		_cache["merge_%d" % i] = _make_stream(_gen_merge(i))
	# 콤보 캐싱 (1~10)
	for i in range(1, 11):
		_cache["combo_%d" % i] = _make_stream(_gen_combo(i))
	# tick 캐싱 (urgency 0.0~1.0, 0.1 단위)
	for i in range(11):
		_cache["tick_%d" % i] = _make_stream(_gen_tick(i * 0.1))
	# AudioStreamPlayer 풀 생성
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = &"Master"
		tree.root.add_child(player)
		_pool.append(player)

static func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	audio.stereo = false
	audio.data = data
	return audio

static func _get_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	# 모든 풀 사용 중이면 첫 번째 재활용
	return _pool[0]

static func play_drop(tree: SceneTree):
	_ensure_init(tree)
	_play_cached("drop", 0.4)

static func play_merge(tree: SceneTree, level: int):
	_ensure_init(tree)
	var key = "merge_%d" % clampi(level, 0, 9)
	_play_cached(key, 0.5)

static func play_combo(tree: SceneTree, combo: int):
	_ensure_init(tree)
	var key = "combo_%d" % clampi(combo, 1, 10)
	_play_cached(key, 0.45)

static func play_countdown_tick(tree: SceneTree, urgency: float):
	_ensure_init(tree)
	var idx = clampi(int(urgency * 10.0), 0, 10)
	_play_cached("tick_%d" % idx, 0.2 + urgency * 0.15)

static func play_countdown_warn(tree: SceneTree):
	_ensure_init(tree)
	_play_cached("warn", 0.35)

static func play_game_over(tree: SceneTree):
	_ensure_init(tree)
	_play_cached("gameover", 0.5)

static func _ensure_init(tree: SceneTree):
	if not _initialized:
		init(tree)

static func _play_cached(key: String, vol: float):
	if not _cache.has(key):
		return
	var player = _get_player()
	player.stream = _cache[key]
	player.volume_db = linear_to_db(vol)
	player.play()

# === 사운드 생성 ===

static func _gen_drop() -> PackedByteArray:
	var sr = 22050
	var dur = 0.12
	var n = int(sr * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t = float(i) / sr
		var env = pow(1.0 - t / dur, 3.0)
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
		var freq = base_freq + t * 200.0
		var s = sin(t * freq * TAU) * 0.5
		s += sin(t * freq * 1.498 * TAU) * 0.3
		s += sin(t * freq * 2.0 * TAU) * 0.15
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
		var freq = 300.0 - t * 200.0
		var s = sin(t * max(freq, 60) * TAU) * 0.6
		s += sin(t * max(freq * 0.5, 30) * TAU) * 0.3
		s *= env
		var v = int(clamp(s * 14000, -32768, 32767))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return data
