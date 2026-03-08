# 다음 공 미리보기
extends Node2D

var preview_level: int = 0

func set_level(lvl: int):
	preview_level = lvl
	queue_redraw()

func _draw():
	var data = StockData.get_level(preview_level)
	var r = min(data.radius, 22)
	
	# 그림자
	draw_circle(Vector2(1, 2), r, Color(0, 0, 0, 0.2))
	# 메인
	draw_circle(Vector2.ZERO, r, data.color)
	# 하이라이트
	draw_circle(Vector2(-r * 0.2, -r * 0.25), r * 0.3, Color(1, 1, 1, 0.25))
	# 테두리
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, data.color.darkened(0.2), 1.5)
	
	var font = ThemeDB.fallback_font
	var fs = int(clamp(r * 0.5, 8, 13))
	var text = data.label
	var ts = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2(-ts.x / 2, fs / 3), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
