# 메인 게임 로직
extends Node2D

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

@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var next_preview: Node2D = $UI/NextPreview
@onready var drop_guide: Line2D = $DropGuide

var ball_scene: PackedScene
var ad_manager: Node = null

func _ready():
	# AdMob 초기화
	ad_manager = Node.new()
	ad_manager.set_script(load("res://scripts/ad_manager.gd"))
	add_child(ad_manager)
	# 화면 크기에 맞춰 레이아웃 조정
	var vp = get_viewport_rect().size
	screen_w = vp.x
	screen_h = vp.y
	
	C_LEFT = 15.0
	C_RIGHT = screen_w - 15.0
	C_TOP = 120.0
	C_BOTTOM = screen_h - 20.0
	DROP_Y = 70.0
	pendulum_x = screen_w / 2.0
	
	# 벽 물리 업데이트
	_setup_walls()
	
	ball_scene = _create_ball_scene()
	next_preview.set_script(load("res://scripts/next_preview.gd"))
	next_level = randi_range(0, StockData.MAX_DROP_LEVEL)
	_load_best_score()
	_update_ui()
	_layout_ui()
	queue_redraw()

func _setup_walls():
	var walls = $Walls
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
	# 점수 (좌상단)
	score_label.position = Vector2(C_LEFT, 8)
	score_label.size = Vector2(300, 40)
	
	# 최고점수 (좌상단 아래)
	best_label.position = Vector2(C_LEFT, 38)
	best_label.size = Vector2(200, 30)
	
	# 다음 공 미리보기 (우상단)
	next_preview.position = Vector2(C_RIGHT - 40, 50)
	
	# 가이드 라인
	drop_guide.width = 1.5
	drop_guide.default_color = Color(1, 1, 1, 0.2)

func _create_ball_scene() -> PackedScene:
	var scene = PackedScene.new()
	var body = RigidBody2D.new()
	body.name = "Ball"
	body.set_script(load("res://scripts/ball.gd"))
	body.gravity_scale = 1.0
	body.contact_monitor = true
	body.max_contacts_reported = 4
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	body.add_child(collision)
	collision.owner = body
	
	scene.pack(body)
	return scene

func _input(event):
	if game_over:
		if event is InputEventMouseButton and event.pressed:
			_restart()
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
	pendulum_speed = 200.0 + min(ball_count / 10.0, 15.0) * 20.0
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
		
		# 카운트다운 (사운드 비활성화 상태)
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
			if child.position.y < C_TOP and abs(child.linear_velocity.y) < 50:
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
	if score > best_score:
		best_score = score
		_save_best_score()
		_show_message("🏆 새 기록!\n시총: " + _format_score(score) + "\n\n탭하여 재시작")
	else:
		_show_message("Game Over!\n시총: " + _format_score(score) + "\n최고: " + _format_score(best_score) + "\n\n탭하여 재시작")

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

func _save_best_score():
	var file = FileAccess.open("user://best_score.dat", FileAccess.WRITE)
	if file:
		file.store_32(best_score)

func _load_best_score():
	var file = FileAccess.open("user://best_score.dat", FileAccess.READ)
	if file:
		best_score = file.get_32()

func _draw():
	# 배경
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0.06, 0.07, 0.10), true)
	
	# 컨테이너 배경 (약간 밝게)
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
	if can_drop and not game_over:
		var bar_y = C_TOP - 45.0
		var bar_w = C_RIGHT - C_LEFT
		var remain_w = bar_w * (1.0 - inflate_amount)
		var bar_color = Color(0.3, 0.85, 0.3).lerp(Color(1.0, 0.15, 0.15), inflate_amount)
		draw_rect(Rect2(C_LEFT, bar_y, bar_w, 5), Color(0.15, 0.15, 0.2), true)
		draw_rect(Rect2(C_LEFT, bar_y, remain_w, 5), bar_color, true)
		
		# 현재 공 위치에 미리보기
		var pd = StockData.get_level(next_level)
		var pr = pd.radius * (1.0 + inflate_amount * 0.5)
		draw_circle(Vector2(pendulum_x, DROP_Y), pr, Color(pd.color.r, pd.color.g, pd.color.b, 0.35))
	
	# 드롭 영역 상단 바
	draw_rect(Rect2(C_LEFT, 55, C_RIGHT - C_LEFT, 35), Color(1, 1, 1, 0.02), true)
	
	# "다음" 텍스트
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(C_RIGHT - 70, 25), "다음", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.7))
