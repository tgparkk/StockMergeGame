# 게임 드로잉 헬퍼 — main.gd에서 분리된 _draw 관련 로직
extends RefCounted

class_name GameDraw

## 게임플레이 화면 드로잉
static func draw_gameplay(canvas: CanvasItem, ctx: Dictionary):
	var C_LEFT: float = ctx.C_LEFT
	var C_RIGHT: float = ctx.C_RIGHT
	var C_TOP: float = ctx.C_TOP
	var C_BOTTOM: float = ctx.C_BOTTOM
	var screen_w: float = ctx.screen_w
	var screen_h: float = ctx.screen_h
	var danger_pulse: float = ctx.danger_pulse
	var game_over_timer: float = ctx.game_over_timer
	var can_drop: bool = ctx.can_drop
	var game_over: bool = ctx.game_over
	var is_playing: bool = ctx.is_playing
	var inflate_amount: float = ctx.inflate_amount
	var pendulum_x: float = ctx.pendulum_x
	var next_level: int = ctx.next_level
	var combo_flash: float = ctx.combo_flash
	var combo_flash_color: Color = ctx.combo_flash_color
	var combo_count: int = ctx.combo_count
	var combo_timer: float = ctx.combo_timer
	var combo_scale_punch: float = ctx.combo_scale_punch

	# 컨테이너 배경
	canvas.draw_rect(Rect2(C_LEFT, C_TOP - 40, C_RIGHT - C_LEFT, C_BOTTOM - C_TOP + 42), Color(0.10, 0.11, 0.16), true)

	# 컨테이너 벽
	var wall_color = Color(0.35, 0.4, 0.5)
	canvas.draw_line(Vector2(C_LEFT, C_BOTTOM), Vector2(C_RIGHT, C_BOTTOM), wall_color, 3.0)
	canvas.draw_line(Vector2(C_LEFT, C_TOP - 40), Vector2(C_LEFT, C_BOTTOM), wall_color, 3.0)
	canvas.draw_line(Vector2(C_RIGHT, C_TOP - 40), Vector2(C_RIGHT, C_BOTTOM), wall_color, 3.0)

	# 경고선
	var danger_alpha = 0.3
	if danger_pulse > 0:
		danger_alpha = 0.3 + abs(sin(danger_pulse)) * 0.7
	canvas.draw_dashed_line(Vector2(C_LEFT + 3, C_TOP), Vector2(C_RIGHT - 3, C_TOP), Color(1, 0.2, 0.2, danger_alpha), 2.0, 8.0)

	# 위험 비네트
	if game_over_timer > 0.5:
		var va = min(game_over_timer / 2.0, 0.25) * abs(sin(danger_pulse))
		canvas.draw_rect(Rect2(0, 0, screen_w, screen_h), Color(1, 0, 0, va), true)

	# 타이머 바
	if can_drop and not game_over and is_playing:
		var DROP_Y: float = ctx.DROP_Y
		var bar_y = C_TOP - 45.0
		var bar_w = C_RIGHT - C_LEFT
		var remain_w = bar_w * (1.0 - inflate_amount)
		var bar_color = Color(0.3, 0.85, 0.3).lerp(Color(1.0, 0.15, 0.15), inflate_amount)
		canvas.draw_rect(Rect2(C_LEFT, bar_y, bar_w, 5), Color(0.15, 0.15, 0.2), true)
		canvas.draw_rect(Rect2(C_LEFT, bar_y, remain_w, 5), bar_color, true)

		var pd = StockData.get_level(next_level)
		var pr = pd.radius * (1.0 + inflate_amount * 0.5)
		canvas.draw_circle(Vector2(pendulum_x, DROP_Y), pr, Color(pd.color.r, pd.color.g, pd.color.b, 0.35))

	# 드롭 영역 상단 바
	canvas.draw_rect(Rect2(C_LEFT, 55, C_RIGHT - C_LEFT, 35), Color(1, 1, 1, 0.02), true)

	# 콤보 시각 효과: 화면 테두리 플래시 + 색조 오버레이
	if combo_flash > 0:
		var flash_alpha = combo_flash * 0.6
		# 화면 가장자리 글로우 (상하좌우)
		var glow_size = 15.0
		var fc = Color(combo_flash_color.r, combo_flash_color.g, combo_flash_color.b, flash_alpha)
		canvas.draw_rect(Rect2(C_LEFT, C_TOP - 40, C_RIGHT - C_LEFT, glow_size), fc, true)  # 상단
		canvas.draw_rect(Rect2(C_LEFT, C_BOTTOM - glow_size, C_RIGHT - C_LEFT, glow_size), fc, true)  # 하단
		canvas.draw_rect(Rect2(C_LEFT, C_TOP - 40, glow_size, C_BOTTOM - C_TOP + 42), fc, true)  # 좌측
		canvas.draw_rect(Rect2(C_RIGHT - glow_size, C_TOP - 40, glow_size, C_BOTTOM - C_TOP + 42), fc, true)  # 우측

	# 콤보 카운터 표시 (활성 콤보 중)
	if combo_count > 1 and combo_timer > 0:
		var combo_font = ThemeDB.fallback_font
		var combo_text = str(combo_count) + "x"
		var combo_fs = 48
		var ct = clamp(combo_timer / 1.5, 0.0, 1.0)
		var combo_alpha = ct
		var punch = 1.0 + combo_scale_punch
		var cts = combo_font.get_string_size(combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(combo_fs * punch))
		var combo_color = Color(1, 1, 0.3, combo_alpha).lerp(Color(1, 0.3, 0.1, combo_alpha), clamp((combo_count - 1) / 8.0, 0.0, 1.0))
		# 그림자
		canvas.draw_string(combo_font, Vector2(C_RIGHT - 70 - cts.x / 2 + 2, C_TOP + 52), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(combo_fs * punch), Color(0, 0, 0, combo_alpha * 0.5))
		canvas.draw_string(combo_font, Vector2(C_RIGHT - 70 - cts.x / 2, C_TOP + 50), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(combo_fs * punch), combo_color)

	# "다음" 텍스트
	var font = ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(C_RIGHT - 70, 25), "다음", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.7))

## 타이틀 화면 드로잉
static func draw_title(canvas: CanvasItem, ctx: Dictionary):
	var screen_w: float = ctx.screen_w
	var screen_h: float = ctx.screen_h
	var anim_t: float = ctx.anim_t

	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0

	# 장식: 미묘한 그라데이션 패널
	var panel_y = screen_h * 0.15
	var panel_h = 200.0
	canvas.draw_rect(Rect2(40, panel_y, screen_w - 80, panel_h), Color(0.1, 0.1, 0.18, 0.7), true)
	# 패널 테두리
	canvas.draw_rect(Rect2(40, panel_y, screen_w - 80, panel_h), Color(0.35, 0.38, 0.55, 0.5), false, 2.0)

	# 타이틀
	var title = "시총 키우기"
	var title_size = 40
	var ts = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	var title_y = panel_y + 80
	# 글로우 효과
	var glow_alpha = 0.15 + sin(anim_t * 2.0) * 0.1
	canvas.draw_string(font, Vector2(cx - ts.x / 2 + 2, title_y + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.3, 0.4, 1.0, glow_alpha))
	canvas.draw_string(font, Vector2(cx - ts.x / 2, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1, 1, 0.85))

	# 서브타이틀
	var sub = "주식 머지 게임"
	var sub_size = 20
	var ss = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size)
	canvas.draw_string(font, Vector2(cx - ss.x / 2, title_y + 45), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.65, 0.68, 0.8))

	# 장식 아이콘들
	var icons = ["🌱", "📈", "🚀", "🦄", "🔔", "👑"]
	var icon_y = screen_h * 0.42
	var spacing = (screen_w - 80) / icons.size()
	for i in range(icons.size()):
		var ix = 40 + spacing * (i + 0.5)
		var bounce = sin(anim_t * 1.5 + i * 0.8) * 8
		canvas.draw_string(font, Vector2(ix - 10, icon_y + bounce), icons[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

## 오버레이 (일시정지 등)
static func draw_overlay(canvas: CanvasItem, ctx: Dictionary, title: String):
	var screen_w: float = ctx.screen_w
	var screen_h: float = ctx.screen_h

	# 반투명 오버레이
	canvas.draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.65), true)

	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0

	# 타이틀
	var ts = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	canvas.draw_string(font, Vector2(cx - ts.x / 2, screen_h * 0.28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1))

## 게임오버 패널
static func draw_game_over_panel(canvas: CanvasItem, ctx: Dictionary):
	var screen_w: float = ctx.screen_w
	var screen_h: float = ctx.screen_h
	var score: int = ctx.score
	var best_score: int = ctx.best_score
	var games_played: int = ctx.games_played

	# 반투명 오버레이
	canvas.draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, 0.7), true)

	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0

	# 패널
	var pw = 320.0
	var ph = 260.0
	var px = cx - pw / 2
	var py = screen_h * 0.22
	canvas.draw_rect(Rect2(px, py, pw, ph), Color(0.1, 0.11, 0.18), true)
	canvas.draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.42, 0.55), false, 2.0)

	# 새 기록?
	var is_new_best = score >= best_score and score > 0
	var header = "🏆 새 기록!" if is_new_best else "Game Over"
	var header_color = Color(1, 1, 0.4) if is_new_best else Color(1, 0.6, 0.6)
	var hs = font.get_string_size(header, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	canvas.draw_string(font, Vector2(cx - hs.x / 2, py + 45), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, header_color)

	# 점수
	var score_text = "시총: " + _format_score(score)
	var sc_size = 32
	var scs = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sc_size)
	canvas.draw_string(font, Vector2(cx - scs.x / 2, py + 100), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sc_size, Color(1, 1, 1))

	# 최고점수
	var best_text = "최고: " + _format_score(best_score)
	var bs = font.get_string_size(best_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	canvas.draw_string(font, Vector2(cx - bs.x / 2, py + 140), best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.8))

	# 게임 수
	var games_text = "총 " + str(games_played) + "게임 플레이"
	var gs = font.get_string_size(games_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	canvas.draw_string(font, Vector2(cx - gs.x / 2, py + 170), games_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.55, 0.65))

## 기록 화면
static func draw_records(canvas: CanvasItem, ctx: Dictionary):
	var screen_w: float = ctx.screen_w
	var screen_h: float = ctx.screen_h
	var stats: Dictionary = ctx.stats

	var font = ThemeDB.fallback_font
	var cx = screen_w / 2.0

	# 타이틀
	var title = "📊 기록"
	var ts = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	canvas.draw_string(font, Vector2(cx - ts.x / 2, screen_h * 0.12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1))

	# 패널
	var pw = 380.0
	var ph = 320.0
	var px = cx - pw / 2
	var py = screen_h * 0.18
	canvas.draw_rect(Rect2(px, py, pw, ph), Color(0.1, 0.11, 0.18, 0.9), true)
	canvas.draw_rect(Rect2(px, py, pw, ph), Color(0.35, 0.38, 0.55, 0.5), false, 2.0)

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
		canvas.draw_string(font, Vector2(px + 30, iy), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.78, 0.9))
		# 값
		var vs = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 24)
		canvas.draw_string(font, Vector2(px + pw - 30 - vs.x, iy), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 0.85))

		# 구분선
		iy += 15
		canvas.draw_line(Vector2(px + 20, iy), Vector2(px + pw - 20, iy), Color(0.25, 0.26, 0.35), 1.0)
		iy += 50

## 유틸리티 함수
static func _format_score(s: int) -> String:
	if s >= 10000:
		return str(s / 10000) + "." + str((s % 10000) / 1000) + "만"
	elif s >= 1000:
		return str(s / 1000) + "," + str(s % 1000).pad_zeros(3)
	return str(s)

static func _get_level_name(lvl: int) -> String:
	if lvl <= 0:
		return "-"
	var data = StockData.get_level(lvl)
	return data.emoji + " " + data.name
