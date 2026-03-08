# 게임 UI 헬퍼 — main.gd에서 분리된 버튼/UI 관련 로직
extends RefCounted

class_name GameUI

## 버튼 초기화 및 정리
static func clear_buttons(buttons: Dictionary, ui_node: Node):
	for key in buttons:
		if is_instance_valid(buttons[key]):
			buttons[key].queue_free()
	buttons.clear()

## 범용 버튼 생성
static func make_button(ui_node: Node, text: String, pos: Vector2, size: Vector2, callback: Callable, font_size: int = 24) -> Button:
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
	ui_node.add_child(btn)
	return btn

## 타이틀 화면 버튼 생성
static func create_title_buttons(ui_node: Node, buttons: Dictionary, screen_w: float, screen_h: float, on_start: Callable, on_records: Callable):
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 56.0
	var by = screen_h * 0.55

	buttons["start"] = make_button(ui_node, "🎮 게임 시작", Vector2(cx - bw/2, by), Vector2(bw, bh), on_start, 26)
	buttons["records"] = make_button(ui_node, "📊 기록", Vector2(cx - bw/2, by + 75), Vector2(bw, bh), on_records, 26)

## 일시정지 버튼 생성
static func create_pause_button(ui_node: Node, buttons: Dictionary, screen_w: float, on_pause: Callable):
	var btn = make_button(ui_node, "⏸", Vector2(screen_w - 55, 75), Vector2(45, 45), on_pause, 20)
	buttons["pause"] = btn

## 일시정지 메뉴 버튼
static func create_pause_menu_buttons(ui_node: Node, buttons: Dictionary, screen_w: float, screen_h: float, on_resume: Callable, on_restart: Callable, on_home: Callable):
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 54.0
	var by = screen_h * 0.38

	buttons["resume"] = make_button(ui_node, "▶️ 계속하기", Vector2(cx - bw/2, by), Vector2(bw, bh), on_resume, 24)
	buttons["restart_p"] = make_button(ui_node, "🔄 다시하기", Vector2(cx - bw/2, by + 70), Vector2(bw, bh), on_restart, 24)
	buttons["home_p"] = make_button(ui_node, "🏠 메인으로", Vector2(cx - bw/2, by + 140), Vector2(bw, bh), on_home, 24)

## 게임오버 버튼
static func create_game_over_buttons(ui_node: Node, buttons: Dictionary, screen_w: float, screen_h: float, can_continue: bool, on_continue: Callable, on_restart: Callable, on_home: Callable):
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 54.0
	var by = screen_h * 0.52

	# 광고 보고 이어하기 (1회 제한, 리워드 광고 준비된 경우만)
	if can_continue:
		buttons["continue_ad"] = make_button(ui_node, "🎬 광고 보고 이어하기", Vector2(cx - bw/2, by), Vector2(bw, bh), on_continue, 20)
		by += 70

	buttons["restart_go"] = make_button(ui_node, "🔄 다시하기", Vector2(cx - bw/2, by), Vector2(bw, bh), on_restart, 24)
	buttons["home_go"] = make_button(ui_node, "🏠 메인으로", Vector2(cx - bw/2, by + 70), Vector2(bw, bh), on_home, 24)

## 기록 화면 버튼
static func create_records_buttons(ui_node: Node, buttons: Dictionary, screen_w: float, screen_h: float, on_back: Callable):
	var cx = screen_w / 2.0
	var bw = 220.0
	var bh = 54.0
	buttons["back"] = make_button(ui_node, "🔙 돌아가기", Vector2(cx - bw/2, screen_h * 0.75), Vector2(bw, bh), on_back, 24)
