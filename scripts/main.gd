# 메인 게임 로직
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

var ball_scene: PackedScene
var ad_manager: Node = null

# UI 버튼들
var _buttons: Dictionary = {}
var _title_anim_t: float = 0.0

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
	
	ball_scene = _create_ball_scene()
	next_preview.set_script(load("res://scripts/next_preview.gd"))
	next_level = randi_range(0, StockData.MAX_DROP_LEVEL)
	_load_stats()
	best_score = stats.best_score
	_update_ui()
	_layout_ui()
	_set_state(State.TITLE)

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

func _create_ball_scene() -> PackedScene:
	var scene = PackedScene.new()
	var body = RigidBody2D.new()
	body.name = "Ball"
	body.set_script(load("res://scripts/ball.gd"))
	body.gravity_scale = 1.0
	body.contact_monitor = true
	body.max_contacts_reported = 8
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	body.add_child(collision)
	collision.owner = body
	
	scene.pack(body)
	return scene

# ── 상태 관리 ──

func _set_state(new_state: State):
	state = new_state
	_clear_buttons()
	
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
			_create_title_buttons()
		State.PLAYING:
			get_tree().paused = false
			_show_gameplay()
			_create_pause_button()
		State.PAUSED:
			get_tree().paused = true
			_create_pause_menu_buttons()
		State.GAME_OVER:
			get_tree().paused = false
			_create_game_over_buttons()
		State.RECORDS:
			get_tree().paused = false
			_hide_gameplay()
			_create_records_buttons()
	
	queue_redraw()

func _hide_gameplay():
	score_label.visible = false
	best_label.visible = false
	next_preview.visible = false
	drop_guide.visible = false
	for child in get_children():
		if child is RigidBody2D:
			child.visible = false

func _show_gameplay():
	score_label.visible = true
	best_label.visible = true
	next_preview.visible = true
	for child in get_children():
		if child is RigidBody2D:
			child.visible = true

# ── 버튼 생성 헬퍼 ──

func _clear_buttons():
	for key in _buttons:
		if is_instance_valid(_buttons[key]):
			_buttons[key].queue_free()
	_buttons.clear()

func _make_button(text: String, pos: Vector2, size: Vector2, callback: Callable, font_size: int = 24) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.6))
	
	# 다크 테마 스타일
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.16, 0.25)
	normal_style.border_color = Color(0.4, 0.42, 0.55)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(12)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.22, 0.33)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.11, 0.18)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.pressed.connect(callback)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.add_child(btn)
	return btn

func _create_title_buttons():
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 56.0
	var by = screen_h * 0.55
	
	_buttons["start"] = _make_button("🎮 게임 시작", Vector2(cx - bw/2, by), Vector2(bw, bh), _on_start_pressed, 26)
	_buttons["records"] = _make_button("📊 기록", Vector2(cx - bw/2, by + 75), Vector2(bw, bh), _on_records_pressed, 26)

func _create_pause_button():
	var btn = _make_button("⏸", Vector2(screen_w - 55, 75), Vector2(45, 45), _on_pause_pressed, 20)
	_buttons["pause"] = btn

func _create_pause_menu_buttons():
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 54.0
	var by = screen_h * 0.38
	
	_buttons["resume"] = _make_button("▶️ 계속하기", Vector2(cx - bw/2, by), Vector2(bw, bh), _on_resume_pressed, 24)
	_buttons["restart_p"] = _make_button("🔄 다시하기", Vector2(cx - bw/2, by + 70), Vector2(bw, bh), _on_restart_pressed, 24)
	_buttons["home_p"] = _make_button("🏠 메인으로", Vector2(cx - bw/2, by + 140), Vector2(bw, bh), _on_home_pressed, 24)

func _create_game_over_buttons():
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 54.0
	var by = screen_h * 0.58
	
	_buttons["restart_go"] = _make_button("🔄 다시하기", Vector2(cx - bw/2, by), Vector2(bw, bh), _on_restart_pressed, 24)
	_buttons["home_go"] = _make_button("🏠 메인으로", Vector2(cx - bw/2, by + 70), Vector2(bw, bh), _on_home_pressed, 24)

func _create_records_buttons():
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 54.0
	_buttons["back"] = _make_button("🔙 돌아가기", Vector2(cx - bw/2, screen_h * 0.75), Vector2(bw, bh), _on_back_pressed, 24)

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
	for child in get_children():
		if child is RigidBody2D:
			child.queue_free()
	game_over = false
	game_over_timer = 0.0
	_set_state(State.TITLE)

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

func _drop_ball(x: float):
	can_drop = false
	
	var size_bonus = inflate_amount * 0.5
	
	var ball = ball_scene.instantiate()
	ball.position = Vector2(x, DROP_Y)
	add_child(ball)
	ball.init(next_level, 1.0 + size_bonus)
	ball.connect("body_entered", ball._on_body_entered)
	SFX.play_drop(get_tree())
	
	ball_count += 1
	pendulum_speed = min(200.0 + min(ball_count / 10.0, 15.0) * 15.0, 380.0)
	drop_timer = 0.0
	inflate_amount = 0.0
	last_tick = -1
	
	next_level = randi_range(0, StockData.MAX_DROP_LEVEL)
	_update_ui()
	
	await get_tree().create_timer(0.4).timeout
	can_drop = true

func merge_balls(ball_a, ball_b, pos: Vector2, new_level: int):
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
	var new_ball = ball_scene.instantiate()
	new_ball.position = pos
	add_child(new_ball)
	new_ball.init(new_level)
	new_ball.connect("body_entered", new_ball._on_body_entered)
	
	if new_level == StockData.get_max_level():
		_show_message("🎉 삼성전자 달성!\n시총: " + _format_score(score))

func _spawn_merge_effect(pos: Vector2, color: Color, radius: float):
	var effect = Node2D.new()
	effect.set_script(load("res://scripts/merge_effect.gd"))
	add_child(effect)
	effect.init(pos, color, radius)

func _show_combo(pos: Vector2, combo: int, points: int):
	var label = Label.new()
	label.text = str(combo) + "x COMBO! +" + str(points)
	label.position = pos - Vector2(70, 40)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

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
	
	# 화면 흔들림
	if screen_shake > 0:
		screen_shake -= delta
		var shake_amount = screen_shake * 40
		position = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	else:
		position = Vector2.ZERO
	
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
	
	# 게임오버 체크
	var any_above = false
	for child in get_children():
		if child is RigidBody2D and not child.merging:
			if child.global_position.y < C_TOP and abs(child.linear_velocity.y) < 50:
				any_above = true
				break
	
	if any_above:
		game_over_timer += delta
		if game_over_timer > 2.0:
			_game_over()
	else:
		game_over_timer = 0.0

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
	game_over_timer = 0.0
	combo_count = 0
	combo_timer = 0.0
	ball_count = 0
	pendulum_speed = 200.0
	pendulum_x = screen_w / 2.0
	drop_timer = 0.0
	inflate_amount = 0.0
	last_tick = -1
	can_drop = true
	for child in get_children():
		if child is RigidBody2D:
			child.queue_free()
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
	score_label.text = "💰 " + _format_score(score)
	best_label.text = "🏆 " + _format_score(best_score) if best_score > 0 else ""
	if next_preview.has_method("set_level"):
		next_preview.set_level(next_level)

func _format_score(s: int) -> String:
	if s >= 10000:
		return str(s / 10000) + "." + str((s % 10000) / 1000) + "만"
	elif s >= 1000:
		return str(s / 1000) + "," + str(s % 1000).pad_zeros(3)
	return str(s)

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

# ── 드로우 ──

func _draw():
	# 배경 (항상)
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0.06, 0.07, 0.10), true)
	
	match state:
		State.TITLE:
			_draw_title()
		State.PLAYING:
			_draw_gameplay()
		State.PAUSED:
			_draw_gameplay()
			_draw_overlay("일시정지", "")
		State.GAME_OVER:
			_draw_gameplay()
			_draw_game_over_panel()
		State.RECORDS:
			_draw_records()

func _draw_gameplay():
	# 컨테이너 배경
	draw_rect(Rect2(C_LEFT, C_TOP - 40, C_RIGHT - C_LEFT, C_BOTTOM - C_TOP + 42), Color(0.10, 0.11, 0.16), true)
	
	# 컨테이너 벽
	var wall_color = Color(0.35, 0.4, 0.5)
	draw_line(Vector2(C_LEFT, C_BOTTOM), Vector2(C_RIGHT, C_BOTTOM), wall_color, 3.0)
	draw_line(Vector2(C_LEFT, C_TOP - 40), Vector2(C_LEFT, C_BOTTOM), wall_color, 3.0)
	draw_line(Vector2(C_RIGHT, C_TOP - 40), Vector2(C_RIGHT, C_BOTTOM), wall_color, 3.0)
	
	# 경고선
	var danger_alpha = 0.3
	if danger_pulse > 0:
		danger_alpha = 0.3 + abs(sin(danger_pulse)) * 0.7
	draw_dashed_line(Vector2(C_LEFT + 3, C_TOP), Vector2(C_RIGHT - 3, C_TOP), Color(1, 0.2, 0.2, danger_alpha), 2.0, 8.0)
	
	# 위험 비네트
	if game_over_timer > 0.5:
		var va = min(game_over_timer / 2.0, 0.25) * abs(sin(danger_pulse))
		draw_rect(Rect2(0, 0, screen_w, screen_h), Color(1, 0, 0, va), true)
	
	# 타이머 바
	if can_drop and not game_over and state == State.PLAYING:
		var bar_y = C_TOP - 45.0
		var bar_w = C_RIGHT - C_LEFT
		var remain_w = bar_w * (1.0 - inflate_amount)
		var bar_color = Color(0.3, 0.85, 0.3).lerp(Color(1.0, 0.15, 0.15), inflate_amount)
		draw_rect(Rect2(C_LEFT, bar_y, bar_w, 5), Color(0.15, 0.15, 0.2), true)
		draw_rect(Rect2(C_LEFT, bar_y, remain_w, 5), bar_color, true)
		
		var pd = StockData.get_level(next_level)
		var pr = pd.radius * (1.0 + inflate_amount * 0.5)
		draw_circle(Vector2(pendulum_x, DROP_Y), pr, Color(pd.color.r, pd.color.g, pd.color.b, 0.35))
	
	# 드롭 영역 상단 바
	draw_rect(Rect2(C_LEFT, 55, C_RIGHT - C_LEFT, 35), Color(1, 1, 1, 0.02), true)
	
	# "다음" 텍스트
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(C_RIGHT - 70, 25), "다음", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.7))

func _draw_title():
	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0
	
	# 장식: 미묘한 그라데이션 패널
	var panel_y = screen_h * 0.15
	var panel_h = 200.0
	draw_rect(Rect2(40, panel_y, screen_w - 80, panel_h), Color(0.1, 0.1, 0.18, 0.7), true)
	# 패널 테두리
	draw_rect(Rect2(40, panel_y, screen_w - 80, panel_h), Color(0.35, 0.38, 0.55, 0.5), false, 2.0)
	
	# 타이틀
	var title = "시총 키우기"
	var title_size = 40
	var ts = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	var title_y = panel_y + 80
	# 글로우 효과
	var glow_alpha = 0.15 + sin(_title_anim_t * 2.0) * 0.1
	draw_string(font, Vector2(cx - ts.x / 2 + 2, title_y + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.3, 0.4, 1.0, glow_alpha))
	draw_string(font, Vector2(cx - ts.x / 2, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1, 1, 0.85))
	
	# 서브타이틀
	var sub = "주식 머지 게임"
	var sub_size = 20
	var ss = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size)
	draw_string(font, Vector2(cx - ss.x / 2, title_y + 45), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.65, 0.68, 0.8))
	
	# 장식 아이콘들
	var icons = ["🌱", "📈", "🚀", "🦄", "🔔", "👑"]
	var icon_y = screen_h * 0.42
	var spacing = (screen_w - 80) / icons.size()
	for i in range(icons.size()):
		var ix = 40 + spacing * (i + 0.5)
		var bounce = sin(_title_anim_t * 1.5 + i * 0.8) * 8
		draw_string(font, Vector2(ix - 10, icon_y + bounce), icons[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

func _draw_overlay(title: String, _detail: String):
	# 반투명 오버레이
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.65), true)
	
	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0
	
	# 타이틀
	var ts = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2(cx - ts.x / 2, screen_h * 0.28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1))

func _draw_game_over_panel():
	# 반투명 오버레이
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.7), true)
	
	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0
	
	# 패널
	var pw = 320.0
	var ph = 260.0
	var px = cx - pw / 2
	var py = screen_h * 0.22
	draw_rect(Rect2(px, py, pw, ph), Color(0.1, 0.11, 0.18), true)
	draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.42, 0.55), false, 2.0)
	
	# 새 기록?
	var is_new_best = score >= best_score and score > 0
	var header = "🏆 새 기록!" if is_new_best else "Game Over"
	var header_color = Color(1, 1, 0.4) if is_new_best else Color(1, 0.6, 0.6)
	var hs = font.get_string_size(header, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(cx - hs.x / 2, py + 45), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, header_color)
	
	# 점수
	var score_text = "시총: " + _format_score(score)
	var sc_size = 32
	var scs = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sc_size)
	draw_string(font, Vector2(cx - scs.x / 2, py + 100), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sc_size, Color(1, 1, 1))
	
	# 최고점수
	var best_text = "최고: " + _format_score(best_score)
	var bs = font.get_string_size(best_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(font, Vector2(cx - bs.x / 2, py + 140), best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.8))
	
	# 게임 수
	var games_text = "총 " + str(stats.games_played) + "게임 플레이"
	var gs = font.get_string_size(games_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(cx - gs.x / 2, py + 170), games_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.55, 0.65))

func _draw_records():
	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0
	
	# 타이틀
	var title = "📊 기록"
	var ts = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2(cx - ts.x / 2, screen_h * 0.12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1))
	
	# 패널
	var pw = 380.0
	var ph = 320.0
	var px = cx - pw / 2
	var py = screen_h * 0.18
	draw_rect(Rect2(px, py, pw, ph), Color(0.1, 0.11, 0.18, 0.9), true)
	draw_rect(Rect2(px, py, pw, ph), Color(0.35, 0.38, 0.55, 0.5), false, 2.0)
	
	var items = [
		["🏆 최고 점수", _format_score(stats.best_score)],
		["🎮 총 게임 수", str(stats.games_played) + "회"],
		["🔄 총 합체 수", str(stats.total_merges) + "회"],
		["⭐ 최고 등급", _get_level_name(stats.max_level)],
	]
	
	var iy = py + 55
	for item in items:
		var label_text: String = item[0]
		var value_text: String = item[1]
		
		# 라벨
		draw_string(font, Vector2(px + 30, iy), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.78, 0.9))
		# 값
		var vs = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 24)
		draw_string(font, Vector2(px + pw - 30 - vs.x, iy), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 0.85))
		
		# 구분선
		iy += 15
		draw_line(Vector2(px + 20, iy), Vector2(px + pw - 20, iy), Color(0.25, 0.26, 0.35), 1.0)
		iy += 50

func _get_level_name(lvl: int) -> String:
	if lvl <= 0:
		return "-"
	var data = StockData.get_level(lvl)
	return data.emoji + " " + data.name
