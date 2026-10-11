extends Control
## Flames drawn in code with additive blending. Flame tongues start in the "spawn" band
## (fractions of the height) and rise to the top. stop() lets them burn out, then the node frees itself.

var on := true
var heat := 1.0  # more flames and taller ones
var spawn := Vector2(0.55, 0.95)  # where flames start: from..to, as fractions of the height
var _parts: Array = []  # [pos, vel, life, max_life, radius]
var _acc := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func stop() -> void:
	on = false


func _process(delta: float) -> void:
	if on:
		_acc += delta * size.x * 1.6 * heat
		while _acc >= 1.0:
			_acc -= 1.0
			var life := randf_range(0.35, 0.75) * (0.8 + heat * 0.2)
			_parts.append([Vector2(randf() * size.x, size.y * randf_range(spawn.x, spawn.y)),
				Vector2(randf_range(-12, 12), -randf_range(60, 130) * heat), life, life, randf_range(4.0, 8.5)])
	for p in _parts:
		p[0] += p[1] * delta
		p[1].x += randf_range(-90, 90) * delta  # flicker
		p[2] -= delta
	_parts = _parts.filter(func(p): return p[2] > 0.0)
	if not on and _parts.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var k: float = p[2] / p[3]  # 1 when born, 0 when gone
		var col := Color(1.0, 0.85, 0.35).lerp(Color(1.0, 0.38, 0.04), clampf((1.0 - k) * 1.6, 0, 1))
		col = col.lerp(Color(0.6, 0.04, 0.0), clampf((0.45 - k) * 2.2, 0, 1))
		col.a = k * 0.6
		_tongue(p[0], p[4] * (0.4 + k * 0.6), p[1], col)


## A teardrop: round at the bottom, pointed at the top, leaning with the flame's motion.
func _tongue(c: Vector2, r: float, vel: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(vel.x * 0.06, -r * 2.6)])
	for i in 9:
		var a := -0.3 + i * (PI + 0.6) / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)
