# 메인 게임 로직 — 상태머신 + 게임플레이 코어
# UI 드로잉은 GameDraw, 버튼/UI는 GameUI로 분리
extends Node2D

enum State { TITLE, PLAYING, PAUSED, GAME_OVER, RECORDS }
var state: State = State.TITLE

var score: int = 0
var best_score: int = 0
var next_level: int = 0
var can_drop: bool = true
var game_over: bool = false
var game_over_timer: float = 0.0
var combo_count: int = 0
var combo_timer: float = 0.0
var screen_shake: float = 0.0
var danger_pulse: float = 0.0
var combo_flash: float = 0.0  # 콤보 플래시 타이머
var combo_flash_color: Color = Color(1, 1, 0.3)  # 콤보 플래시 색상
var combo_scale_punch: float = 0.0  # 콤보 스케일 펀치 효과

# 자동 좌우 이동
var pendulum_x: float = 270.0
var pendulum_dir: float = 1.0
var pendulum_speed: float = 200.0
var ball_count: int = 0

# 드롭 타이머 (패널티)
var drop_timer: float = 0.0
const DROP_TIME_LIMIT: float = 3.0
var inflate_amount: float = 0.0
var last_tick: int = -1

# 화면 크기 기반 레이아웃
var screen_w: float = 540.0
var screen_h: float = 960.0
var C_LEFT: float = 20.0
var C_RIGHT: float = 520.0
var C_TOP: float = 130.0
var C_BOTTOM: float = 920.0
var DROP_Y: float = 80.0
var WALL_THICKNESS: float = 4.0
var safe_top: float = 0.0
var safe_bottom: float = 0.0
var safe_left: float = 0.0
var safe_right: float = 0.0

# 통계
var stats: Dictionary = {
	"best_score": 0,
	"games_played": 0,
	"total_merges": 0,
	"max_level": 0,
}

@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var next_preview: Node2D = $UI/NextPreview
@onready var drop_guide: Line2D = $DropGuide

var _ball_script: GDScript = null
var ad_manager: Node = null
var _continue_used: bool = false  # 광고 이어하기 1회 제한

# UI 버튼들
var _buttons: Dictionary = {}
var _title_anim_t: float = 0.0

# 성능 개선: 공(RigidBody2D) 목록 캐싱
var _ball_cache: Array = []
var _ball_cache_dirty: bool = true
var _shake_offset: Vector2 = Vector2.ZERO

func _ready():
	# AdMob 초기화
	ad_manager = Node.new()
	ad_manager.set_script(load("res://scripts/ad_manager.gd"))
	add_child(ad_manager)
	# 화면 크기에 맞춰 레이아웃 조정
	var vp = get_viewport_rect().size
	screen_w = vp.x
	screen_h = vp.y

	# Safe Area 대응 (노치/펀치홀/다이내믹 아일랜드)
	_update_safe_area()

	C_LEFT = max(15.0, safe_left + 5.0)
	C_RIGHT = screen_w - max(15.0, safe_right + 5.0)
	C_TOP = max(130.0, screen_h * 0.14, safe_top + 80.0)
	C_BOTTOM = screen_h - max(90.0, screen_h * 0.10, safe_bottom + 50.0)
	DROP_Y = max(70.0, C_TOP - 50.0)
	pendulum_x = screen_w / 2.0

	_setup_walls()

	_ball_script = load("res://scripts/ball.gd")
	next_preview.set_script(load("res://scripts/next_preview.gd"))
	next_level = randi_range(0, StockData.MAX_DROP_LEVEL)
	_load_stats()
	best_score = stats.best_score
	_update_ui()
	_layout_ui()
	_set_state(State.TITLE)

	# 자식 노드 변화 감지 → 캐시 무효화
	child_entered_tree.connect(_on_child_changed)
	child_exiting_tree.connect(_on_child_changed)

# ── 성능 개선: 공 목록 캐싱 ──

func _on_child_changed(_node: Node):
	_ball_cache_dirty = true

func _get_balls() -> Array:
	if _ball_cache_dirty:
		_ball_cache.clear()
		for child in get_children():
			if child is RigidBody2D:
				_ball_cache.append(child)
		_ball_cache_dirty = false
	return _ball_cache

# ── 초기화 헬퍼 ──

func _update_safe_area():
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		var vp_rect = get_viewport_rect()
		var safe_rect = DisplayServer.get_display_safe_area()
		safe_top = max(0.0, safe_rect.position.y - vp_rect.position.y)
		safe_bottom = max(0.0, (vp_rect.position.y + vp_rect.size.y) - (safe_rect.position.y + safe_rect.size.y))
		safe_left = max(0.0, safe_rect.position.x - vp_rect.position.x)
		safe_right = max(0.0, (vp_rect.position.x + vp_rect.size.x) - (safe_rect.position.x + safe_rect.size.x))
		print("[SafeArea] top=", safe_top, " bottom=", safe_bottom, " left=", safe_left, " right=", safe_right)

func _setup_walls():
	var floor_col = $Walls/Floor
	var left_col = $Walls/LeftWall
	var right_col = $Walls/RightWall

	var floor_shape = RectangleShape2D.new()
	floor_shape.size = Vector2(C_RIGHT - C_LEFT, WALL_THICKNESS)
	floor_col.shape = floor_shape
	floor_col.position = Vector2((C_LEFT + C_RIGHT) / 2, C_BOTTOM + WALL_THICKNESS / 2)

	var wall_h = C_BOTTOM - C_TOP + 60
	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(WALL_THICKNESS, wall_h)
	left_col.shape = left_shape
	left_col.position = Vector2(C_LEFT - WALL_THICKNESS / 2, C_TOP - 30 + wall_h / 2)

	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(WALL_THICKNESS, wall_h)
	right_col.shape = right_shape
	right_col.position = Vector2(C_RIGHT + WALL_THICKNESS / 2, C_TOP - 30 + wall_h / 2)

func _layout_ui():
	var ui_top = max(8.0, safe_top + 4.0)
	score_label.position = Vector2(C_LEFT, ui_top)
	score_label.size = Vector2(screen_w * 0.5, 40)
	best_label.position = Vector2(C_LEFT, ui_top + 30)
	best_label.size = Vector2(screen_w * 0.4, 30)
	# 다음 프리뷰: 우상단, 게임영역 밖 (점수 옆)
	next_preview.position = Vector2(C_RIGHT - 45, ui_top + 42)
	drop_guide.width = 1.5
	drop_guide.default_color = Color(1, 1, 1, 0.2)

func _create_ball() -> RigidBody2D:
	var body = RigidBody2D.new()
	body.gravity_scale = 1.0
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	body.add_child(collision)

	body.set_script(_ball_script)
	return body

# ── 상태 관리 ──

func _set_state(new_state: State):
	state = new_state
	GameUI.clear_buttons(_buttons, $UI)

	var playing_ui = state == State.PLAYING
	score_label.visible = playing_ui
	best_label.visible = playing_ui
	next_preview.visible = playing_ui
	drop_guide.visible = false
	$UI/MessageLabel.visible = false

	match state:
		State.TITLE:
			get_tree().paused = false
			_hide_gameplay()
			GameUI.create_title_buttons($UI, _buttons, screen_w, screen_h, _on_start_pressed, _on_records_pressed)
		State.PLAYING:
			get_tree().paused = false
			_show_gameplay()
			GameUI.create_pause_button($UI, _buttons, screen_w, _on_pause_pressed)
		State.PAUSED:
			get_tree().paused = true
			GameUI.create_pause_menu_buttons($UI, _buttons, screen_w, screen_h, _on_resume_pressed, _on_restart_pressed, _on_home_pressed)
		State.GAME_OVER:
			get_tree().paused = false
			var can_continue = not _continue_used and ad_manager and ad_manager.is_rewarded_ready()
			GameUI.create_game_over_buttons($UI, _buttons, screen_w, screen_h, can_continue, _on_continue_ad_pressed, _on_restart_pressed, _on_home_pressed)
		State.RECORDS:
			get_tree().paused = false
			_hide_gameplay()
			GameUI.create_records_buttons($UI, _buttons, screen_w, screen_h, _on_back_pressed)

	queue_redraw()

func _hide_gameplay():
	score_label.visible = false
	best_label.visible = false
	next_preview.visible = false
	drop_guide.visible = false
	for ball in _get_balls():
		if is_instance_valid(ball):
			ball.visible = false

func _show_gameplay():
	score_label.visible = true
	best_label.visible = true
	next_preview.visible = true
	for ball in _get_balls():
		if is_instance_valid(ball):
			ball.visible = true

# ── 버튼 콜백 ──

func _on_start_pressed():
	_restart()
	_set_state(State.PLAYING)

func _on_records_pressed():
	_set_state(State.RECORDS)

func _on_pause_pressed():
	_set_state(State.PAUSED)

func _on_resume_pressed():
	_set_state(State.PLAYING)

func _on_restart_pressed():
	_restart()
	_set_state(State.PLAYING)

func _on_home_pressed():
	# 공 정리
	for ball in _get_balls():
		if is_instance_valid(ball):
			ball.queue_free()
	game_over = false
	game_over_timer = 0.0
	_set_state(State.TITLE)

func _on_continue_ad_pressed():
	if ad_manager:
		ad_manager.show_rewarded(_on_rewarded_continue)

func _on_rewarded_continue():
	_continue_used = true
	game_over = false
	game_over_timer = 0.0
	# 위험선 위 공들 아래로 밀어주기
	for ball in _get_balls():
		if is_instance_valid(ball) and ball.global_position.y < C_TOP:
			ball.apply_central_impulse(Vector2(0, 300))
	can_drop = true
	drop_timer = 0.0
	inflate_amount = 0.0
	last_tick = -1
	_set_state(State.PLAYING)

func _on_back_pressed():
	_set_state(State.TITLE)

# ── 입력 ──

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			State.PLAYING:
				_set_state(State.PAUSED)
			State.PAUSED:
				_set_state(State.PLAYING)
			State.TITLE, State.RECORDS:
				get_tree().quit()
			State.GAME_OVER:
				_set_state(State.TITLE)

func _input(event):
	if state != State.PLAYING:
		return

	if event is InputEventMouseButton and event.pressed and can_drop:
		_drop_ball(pendulum_x)

# ── 게임 로직 ──

func _drop_ball(x: float):
	can_drop = false

	var size_bonus = inflate_amount * 0.5

	var ball = _create_ball()
	ball.position = Vector2(x, DROP_Y)
	add_child(ball)
	ball.init(next_level, 1.0 + size_bonus)
	ball.connect("body_entered", ball._on_body_entered)
	SFX.play_drop(get_tree())

	ball_count += 1
	# 드롭 속도 증가: 초반 완만하게, 후반 가속 (로그 곡선)
	pendulum_speed = 200.0 + min(log(ball_count + 1.0) / log(2.0) * 30.0, 180.0)
	drop_timer = 0.0
	inflate_amount = 0.0
	last_tick = -1

	next_level = randi_range(0, StockData.MAX_DROP_LEVEL)
	_update_ui()

	await get_tree().create_timer(0.4).timeout
	# 버그 수정: await 후 씬 트리 유효성 확인
	if not is_inside_tree():
		return
	can_drop = true

func merge_balls(ball_a, ball_b, pos: Vector2, new_level: int):
	# 버그 수정: 호출 시점에 이미 해제된 노드인지 확인
	if not is_instance_valid(ball_a) or not is_instance_valid(ball_b):
		return

	var data = StockData.get_level(new_level)

	if combo_timer > 0:
		combo_count += 1
	else:
		combo_count = 1
	combo_timer = 1.5

	var combo_bonus = combo_count if combo_count > 1 else 1
	var gained = data.score * combo_bonus
	score += gained

	# 통계 추적
	stats.total_merges += 1
	if new_level > stats.max_level:
		stats.max_level = new_level

	if combo_count > 1:
		_show_combo(pos, combo_count, gained)

	_update_ui()

	_spawn_merge_effect(pos, data.color, data.radius)
	screen_shake = 0.15 + new_level * 0.05
	SFX.play_merge(get_tree(), new_level)
	if combo_count > 1:
		SFX.play_combo(get_tree(), combo_count)

	ball_a.queue_free()
	ball_b.queue_free()

	await get_tree().process_frame
	# 버그 수정: await 후 씬 트리/게임 상태 유효성 확인
	if not is_inside_tree():
		return

	var new_ball = _create_ball()
	new_ball.position = pos
	add_child(new_ball)
	new_ball.init(new_level)
	new_ball.connect("body_entered", new_ball._on_body_entered)

	if new_level == StockData.get_max_level():
		_show_message("🎉 삼성전자 달성!\n시총: " + GameDraw._format_score(score))

func _spawn_merge_effect(pos: Vector2, color: Color, radius: float):
	var effect = Node2D.new()
	effect.set_script(load("res://scripts/merge_effect.gd"))
	add_child(effect)
	effect.init(pos, color, radius)

func _show_combo(pos: Vector2, combo: int, points: int):
	# 콤보 텍스트 (크기 콤보 횟수에 비례)
	var label = Label.new()
	label.text = str(combo) + "x COMBO! +" + str(points)
	label.position = pos - Vector2(70, 40)
	var font_size = min(22 + combo * 3, 40)
	label.add_theme_font_size_override("font_size", font_size)
	# 콤보 횟수에 따라 색상 변화 (노란색 → 주황 → 빨강)
	var combo_t = clamp((combo - 1) / 8.0, 0.0, 1.0)
	var text_color = Color(1, 1, 0.3).lerp(Color(1, 0.3, 0.1), combo_t)
	label.add_theme_color_override("font_color", text_color)
	add_child(label)

	# 스케일 펀치: 텍스트가 커졌다 작아지는 효과
	label.pivot_offset = Vector2(70, 20)
	label.scale = Vector2(1.5, 1.5)

	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - 80, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.tween_callback(label.queue_free)

	# 화면 플래시 트리거
	combo_flash = 0.4 + combo * 0.05
	combo_flash_color = text_color
	# 콤보 횟수에 비례한 화면 흔들림 증가
	screen_shake = max(screen_shake, 0.1 + combo * 0.06)
	combo_scale_punch = 0.03 + combo * 0.01

# ── 게임 루프 ──

func _process(delta):
	_title_anim_t += delta

	if state != State.PLAYING:
		if state == State.TITLE or state == State.RECORDS:
			queue_redraw()
		return

	if game_over:
		return

	# 펜듈럼 좌우 이동
	if can_drop:
		var margin = 30.0
		pendulum_x += pendulum_dir * pendulum_speed * delta
		if pendulum_x >= C_RIGHT - margin:
			pendulum_x = C_RIGHT - margin
			pendulum_dir = -1.0
		elif pendulum_x <= C_LEFT + margin:
			pendulum_x = C_LEFT + margin
			pendulum_dir = 1.0

		drop_timer += delta
		inflate_amount = clamp(drop_timer / DROP_TIME_LIMIT, 0.0, 1.0)

		var tick_interval = 0.5 if inflate_amount < 0.5 else (0.25 if inflate_amount < 0.8 else 0.12)
		var current_tick = int(drop_timer / tick_interval)
		if current_tick != last_tick and drop_timer > 0.3:
			last_tick = current_tick
			if inflate_amount > 0.8:
				SFX.play_countdown_warn(get_tree())
			elif inflate_amount > 0.3:
				SFX.play_countdown_tick(get_tree(), inflate_amount)

		if drop_timer >= DROP_TIME_LIMIT:
			_drop_ball(pendulum_x)

		drop_guide.points = [Vector2(pendulum_x, DROP_Y + 20), Vector2(pendulum_x, C_BOTTOM)]
		drop_guide.visible = true
		queue_redraw()
	else:
		drop_guide.visible = false

	# 화면 흔들림 (시각 오프셋만 — position 변경은 물리 보간을 깨뜨림)
	if screen_shake > 0:
		screen_shake -= delta
		var shake_amount = screen_shake * 40
		_shake_offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	else:
		_shake_offset = Vector2.ZERO

	# 위험 펄스
	if game_over_timer > 0:
		danger_pulse += delta * 8.0
	else:
		danger_pulse = 0.0

	# 콤보 타이머
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

	# 콤보 시각 효과 타이머
	if combo_flash > 0:
		combo_flash -= delta
	if combo_scale_punch > 0:
		combo_scale_punch = max(combo_scale_punch - delta * 0.3, 0.0)

	# 게임오버 체크 — 캐싱된 공 목록 사용 + 개선된 판정 로직
	# 1) 스폰 애니메이션 중인 공은 제외
	# 2) 속도 전체(x+y)를 고려하여 "안정 상태" 판정
	# 3) 공의 반지름을 고려하여 실제로 경고선 위에 있는지 확인
	var danger_count: int = 0
	for ball in _get_balls():
		if not is_instance_valid(ball) or ball.merging:
			continue
		# 스폰 애니메이션 중인 공은 무시
		if ball.spawn_scale < 1.0:
			continue
		# 공의 상단이 경고선 위에 있는지 확인 (반지름 고려)
		var data = StockData.get_level(ball.level)
		var ball_top = ball.global_position.y - data.radius * ball.size_multiplier
		if ball_top < C_TOP:
			# 속도 전체가 충분히 낮아야 "정착" 상태로 판정
			var speed = ball.linear_velocity.length()
			if speed < 80.0:
				danger_count += 1

	if danger_count > 0:
		game_over_timer += delta
		if game_over_timer > 2.0:
			_game_over()
	else:
		game_over_timer = max(game_over_timer - delta * 0.5, 0.0)  # 서서히 감소 (깜빡임 방지)

func _game_over():
	game_over = true
	SFX.play_game_over(get_tree())
	if ad_manager:
		ad_manager.show_interstitial_on_game_over()

	# 통계 업데이트
	stats.games_played += 1
	if score > best_score:
		best_score = score
	if score > stats.best_score:
		stats.best_score = score
	_save_stats()

	_set_state(State.GAME_OVER)

func _restart():
	score = 0
	game_over = false
	_continue_used = false
	game_over_timer = 0.0
	combo_count = 0
	combo_timer = 0.0
	combo_flash = 0.0
	combo_flash_color = Color(1, 1, 0.3)
	combo_scale_punch = 0.0
	ball_count = 0
	pendulum_speed = 200.0
	pendulum_x = screen_w / 2.0
	drop_timer = 0.0
	inflate_amount = 0.0
	last_tick = -1
	can_drop = true
	for ball in _get_balls():
		if is_instance_valid(ball):
			ball.queue_free()
	next_level = randi_range(0, StockData.MAX_DROP_LEVEL)
	_update_ui()
	$UI/MessageLabel.visible = false

func _show_message(text: String):
	var msg = $UI/MessageLabel
	msg.text = text
	msg.visible = true
	msg.position = Vector2(screen_w / 2 - 150, screen_h / 2 - 80)
	msg.size = Vector2(300, 160)

func _update_ui():
	score_label.text = "💰 " + GameDraw._format_score(score)
	best_label.text = "🏆 " + GameDraw._format_score(best_score) if best_score > 0 else ""
	if next_preview.has_method("set_level"):
		next_preview.set_level(next_level)

# ── 통계 저장/로드 ──

func _save_stats():
	var file = FileAccess.open("user://stats.dat", FileAccess.WRITE)
	if file:
		file.store_var(stats)
	# 하위 호환
	_save_best_score()

func _load_stats():
	var file = FileAccess.open("user://stats.dat", FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Dictionary:
			for key in data:
				stats[key] = data[key]
	else:
		_load_best_score()

func _save_best_score():
	var file = FileAccess.open("user://best_score.dat", FileAccess.WRITE)
	if file:
		file.store_32(best_score)

func _load_best_score():
	var file = FileAccess.open("user://best_score.dat", FileAccess.READ)
	if file:
		best_score = file.get_32()
		stats.best_score = best_score

# ── 드로우 — GameDraw 헬퍼 호출 ──

func _get_draw_context() -> Dictionary:
	return {
		"C_LEFT": C_LEFT, "C_RIGHT": C_RIGHT, "C_TOP": C_TOP, "C_BOTTOM": C_BOTTOM,
		"screen_w": screen_w, "screen_h": screen_h,
		"danger_pulse": danger_pulse, "game_over_timer": game_over_timer,
		"can_drop": can_drop, "game_over": game_over,
		"is_playing": state == State.PLAYING,
		"inflate_amount": inflate_amount, "pendulum_x": pendulum_x,
		"next_level": next_level, "DROP_Y": DROP_Y,
		"anim_t": _title_anim_t,
		"score": score, "best_score": best_score,
		"games_played": stats.games_played,
		"stats": stats,
		"combo_flash": combo_flash, "combo_flash_color": combo_flash_color,
		"combo_count": combo_count, "combo_timer": combo_timer,
		"combo_scale_punch": combo_scale_punch,
	}

func _draw():
	# 화면 흔들림: 캔버스 변환으로 적용 (position 건드리지 않음 — 물리 보간 보호)
	if _shake_offset != Vector2.ZERO:
		draw_set_transform(_shake_offset)

	# 배경 (항상)
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0.06, 0.07, 0.10), true)

	var ctx = _get_draw_context()

	match state:
		State.TITLE:
			GameDraw.draw_title(self, ctx)
		State.PLAYING:
			GameDraw.draw_gameplay(self, ctx)
		State.PAUSED:
			GameDraw.draw_gameplay(self, ctx)
			GameDraw.draw_overlay(self, ctx, "일시정지")
		State.GAME_OVER:
			GameDraw.draw_gameplay(self, ctx)
			GameDraw.draw_game_over_panel(self, ctx)
		State.RECORDS:
			GameDraw.draw_records(self, ctx)
