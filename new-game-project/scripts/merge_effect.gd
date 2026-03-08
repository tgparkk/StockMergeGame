# 합체 이펙트 — 파티클 + 확대 링
extends Node2D

var lifetime: float = 0.0
var max_lifetime: float = 0.6
var color: Color = Color.WHITE
var radius: float = 30.0

func init(pos: Vector2, col: Color, r: float):
	global_position = pos
	color = col
	radius = r

func _process(delta):
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
	queue_redraw()

func _draw():
	var t = lifetime / max_lifetime  # 0 → 1
	var ease_t = 1.0 - pow(1.0 - t, 3)  # ease out
	
	# 확장하는 링
	var ring_r = radius * (1.0 + ease_t * 2.0)
	var ring_alpha = (1.0 - t) * 0.8
	draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, Color(color.r, color.g, color.b, ring_alpha), 3.0)
	
	# 작은 파티클들
	for i in range(8):
		var angle = i * TAU / 8
		var dist = radius * 0.5 + ease_t * radius * 1.5
		var particle_pos = Vector2(cos(angle), sin(angle)) * dist
		var particle_r = (1.0 - t) * 6.0
		var particle_alpha = (1.0 - t) * 0.9
		draw_circle(particle_pos, particle_r, Color(color.r, color.g, color.b, particle_alpha))
	
	# 플래시 (초반에만)
	if t < 0.2:
		var flash_alpha = (1.0 - t / 0.2) * 0.4
		draw_circle(Vector2.ZERO, radius * 1.5, Color(1, 1, 1, flash_alpha))
