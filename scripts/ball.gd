# 주식 공 — 세련된 비주얼
extends RigidBody2D

var level: int = 0
var merging: bool = false
var spawn_scale: float = 0.0
var size_multiplier: float = 1.0

func init(stock_level: int, size_mult: float = 1.0):
	level = stock_level
	size_multiplier = size_mult
	var data = StockData.get_level(level)
	
	var shape = CircleShape2D.new()
	shape.radius = data.radius * size_multiplier
	var col = get_node("CollisionShape2D")
	if col:
		col.shape = shape
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.15
	physics_material_override.friction = 0.9
	
	spawn_scale = 0.3
	queue_redraw()

func _process(delta):
	if spawn_scale < 1.0:
		spawn_scale = min(spawn_scale + delta * 6.0, 1.0)
		scale = Vector2(spawn_scale, spawn_scale)

func _draw():
	var data = StockData.get_level(level)
	var r = data.radius * size_multiplier
	var col = data.color
	var hi = data.highlight
	
	# 그림자
	draw_circle(Vector2(2, 3), r, Color(0, 0, 0, 0.25))
	
	# 메인 원
	draw_circle(Vector2.ZERO, r, col)
	
	# 내부 그라데이션 (밝은 원)
	draw_circle(Vector2(-r * 0.15, -r * 0.2), r * 0.7, Color(hi.r, hi.g, hi.b, 0.25))
	
	# 광택 하이라이트
	draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.3))
	
	# 테두리 (진한 색)
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, col.darkened(0.25), 2.0)
	
	# 이모지 (상단)
	var font = ThemeDB.fallback_font
	var emoji = data.get("emoji", "")
	if emoji != "" and r > 25:
		var es = int(clamp(r * 0.35, 10, 22))
		var ets = font.get_string_size(emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, es)
		draw_string(font, Vector2(-ets.x / 2, -r * 0.15), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, es)
	
	# 시총 텍스트 (중앙)
	var font_size = int(clamp(r * 0.38, 10, 24))
	var text = data.label
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2, r * 0.15 + font_size / 3), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
	
	# 이름 (하단, 큰 공만)
	if r > 40:
		var ns = int(clamp(r * 0.22, 8, 14))
		var name_text = data.name
		var nts = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ns)
		draw_string(font, Vector2(-nts.x / 2, r * 0.45), name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ns, Color(1, 1, 1, 0.6))

func _on_body_entered(body: Node):
	if body is RigidBody2D and body.has_method("try_merge"):
		try_merge(body)

func try_merge(other):
	if other.level == level and not merging and not other.merging:
		if level >= StockData.get_max_level():
			return
		if get_instance_id() > other.get_instance_id():
			return
		
		merging = true
		other.merging = true
		
		var merge_pos = (global_position + other.global_position) / 2
		get_parent().merge_balls(self, other, merge_pos, level + 1)
