extends RefCounted

const AIM_ORIGIN := Vector2(0, -22)
const PIXEL_SCALE := 2.0
const CELL := Rect2i(-8, -16, 16, 16)
const REST := [
	Vector2(0, -13), Vector2(0, -10), Vector2(-1, -6),
	Vector2(-2, -3), Vector2(-3, -1), Vector2(1, -3), Vector2(2, -1),
	Vector2(-2, -8), Vector2(-1, -7), Vector2(2, -8), Vector2(4, -9),
]
const LOW := [
	Vector2(2, -9), Vector2(1, -7), Vector2(-2, -4),
	Vector2(-3, -2), Vector2(-4, -1), Vector2(2, -3), Vector2(2, -1),
	Vector2(-1, -6), Vector2(0, -6), Vector2(3, -5), Vector2(5, -6),
]
const AIR := [
	Vector2(1, -14), Vector2(0, -11), Vector2(-1, -7),
	Vector2(-4, -5), Vector2(-3, -3), Vector2(2, -6), Vector2(3, -4),
	Vector2(-3, -10), Vector2(-4, -8), Vector2(3, -11), Vector2(4, -13),
]
const SLIDE := [
	Vector2(1, -5), Vector2(0, -4), Vector2(-2, -2),
	Vector2(-4, -2), Vector2(-6, -1), Vector2(3, -2), Vector2(7, -1),
	Vector2(-3, -4), Vector2(-5, -3), Vector2(3, -3), Vector2(5, -2),
]
const GUARD := [
	Vector2(-1, -12), Vector2(-1, -9), Vector2(-2, -5),
	Vector2(-4, -3), Vector2(-4, -1), Vector2(2, -3), Vector2(3, -1),
	Vector2(0, -9), Vector2(2, -13), Vector2(3, -9), Vector2(3, -13),
]
const PUNCH := [
	Vector2(2, -13), Vector2(1, -10), Vector2(0, -6),
	Vector2(-3, -3), Vector2(-4, -1), Vector2(2, -3), Vector2(4, -1),
	Vector2(-1, -8), Vector2(0, -9), Vector2(4, -10), Vector2(7, -10),
]
const SLOUCH := [
	Vector2(2, -11), Vector2(1, -8), Vector2(-1, -5),
	Vector2(-3, -3), Vector2(-4, -1), Vector2(2, -3), Vector2(3, -1),
	Vector2(-2, -6), Vector2(-1, -4), Vector2(3, -6), Vector2(4, -4),
]

static func muzzle_length(gear: Dictionary) -> float:
	return 22.0 if gear.size <= 9 else 15.0 + float(gear.size) * 0.66

static func _blend(body: Array, target: Array, weight: float) -> void:
	for index in body.size():
		body[index] = body[index].lerp(target[index], weight)

static func _body(f, gear: Dictionary) -> Array:
	var body := REST.duplicate()
	body[0].y += sin(f.motion_clock * 4.0) * 0.45
	_blend(body, LOW, maxf(f.visual_crouch, sin(f.landing / 0.18 * PI) * 0.50))
	var speed: float = absf(f.move_speed)
	var stride: float = smoothstep(5.0, 160.0, speed) * (1.0 - f.visual_crouch * 0.58)
	var gait: float = f.stride_distance * TAU / 39.0
	var reach := cos(gait) * stride * 4.8
	var lift := sin(gait) * stride * 3.0
	body[3] += Vector2(reach * 0.5, -maxf(lift, 0.0))
	body[4] += Vector2(reach, -maxf(lift, 0.0))
	body[5] -= Vector2(reach * 0.5, maxf(-lift, 0.0))
	body[6] -= Vector2(reach, maxf(-lift, 0.0))
	body[7] += Vector2(-reach * 0.3, 0.65 * stride)
	body[8] += Vector2(-reach * 0.6, 1.0 * stride)
	body[9] += Vector2(reach * 0.35, 0.65 * stride)
	body[10] += Vector2(reach * 0.65, 1.0 * stride)
	body[0].x += stride * 2.0
	body[1].x += stride
	var air := AIR.duplicate()
	air[6].y += smoothstep(-140.0, 160.0, f.velocity.y) * 2.0
	_blend(body, air, f.visual_air)
	if f.climbing:
		var step := sin(f.position.y * 0.38) * 1.8
		body[7] = Vector2(-2, -12)
		body[8] = Vector2(-3, -13 + step)
		body[9] = Vector2(2, -11)
		body[10] = Vector2(3, -13 - step)
		body[4].y = -2 + step
		body[6].y = -2 - step
	if f.slide > 0.0:
		_blend(body, SLIDE, minf(1.0, f.slide * 12.0))
	_blend(body, GUARD, f.visual_guard)
	if f.pickup > 0.0:
		_blend(body, LOW, sin(f.pickup / 0.28 * PI))
		body[10].y += sin(f.pickup / 0.28 * PI) * 4.0
	if f.strike > 0.0:
		var progress: float = 1.0 - f.strike / 0.32
		var windup := sin(clampf(progress / 0.20, 0.0, 1.0) * PI)
		body[9].x -= windup * 3.0
		body[10].x -= windup * 5.0
		_blend(body, PUNCH, smoothstep(0.08, 0.30, progress) * (1.0 - smoothstep(0.39, 1.0, progress)))
	if f.locked():
		var hurt := SLOUCH.duplicate()
		hurt[0].x -= smoothstep(0.0, 0.22, f.stagger) * 3.0
		_blend(body, hurt, smoothstep(0.0, 0.18, maxf(f.stagger, maxf(f.exhausted, f.knocked))))
	if f.aiming and f.has_gun() and not gear.is_empty():
		var forward := Vector2(cos(f.elevation), sin(f.elevation))
		var under := Vector2(-forward.y, forward.x)
		var anchor := AIM_ORIGIN / PIXEL_SCALE
		var pistol: bool = gear.size <= 9
		var grip := 6.5 if pistol else 4.0
		var support := 6.5 if pistol else 7.0
		var recoil: float = f.recoil * 7.0
		body[7] = anchor + forward * (support / 2.0) + under * 1.5
		body[8] = anchor + forward * (support - recoil) + under * 0.5
		body[9] = anchor + forward * (grip / 2.0) + under * (1.0 if pistol else 2.5)
		body[10] = anchor + forward * (grip - recoil) + under
	elif f.item != null and f.reload > 0.0:
		body[8] = Vector2(1, -6 + sin(f.reload * 8.0))
		body[10] = Vector2(3, -7)
	return body

static func _pixel(canvas: Node2D, at: Vector2i, color: Color) -> void:
	if CELL.has_point(at):
		canvas.draw_rect(Rect2(Vector2(at), Vector2.ONE), color)

static func _segment(canvas: Node2D, from: Vector2, to: Vector2, body: Color, edge: Color) -> void:
	var delta := to - from
	var steps := maxi(1, ceili(maxf(absf(delta.x), absf(delta.y))))
	for index in range(steps + 1):
		var at := Vector2i(from.lerp(to, float(index) / steps).round())
		_pixel(canvas, at - Vector2i(0, 1), edge)
		_pixel(canvas, at, body)

static func paint(canvas: Node2D, f, gear: Dictionary) -> void:
	var body := _body(f, gear)
	var fall := smoothstep(0.0, 0.22, 1.5 - f.knocked) * smoothstep(0.0, 0.24, f.knocked)
	if f.hp == 0:
		fall = 1.0
	var tilt: float = float(f.knock_side) * fall * 1.51
	var feet: Vector2 = f.position.round() - Vector2(0, 3.0 * fall)
	var color := Color("020205")
	var rim := Color("a07283") if f.team == 0 else Color("b77a6d")
	var far := rim.darkened(0.66)
	if f.flash > 0.0:
		rim = rim.lerp(Color("edb28b"), f.flash / 0.14)
	canvas.draw_set_transform(feet, tilt, Vector2(f.facing * PIXEL_SCALE, PIXEL_SCALE))
	for index in [3, 5]:
		_segment(canvas, body[2], body[index], color, far if index == 3 else rim)
		_segment(canvas, body[index], body[index + 1], color, far if index == 3 else rim)
		var foot: Vector2 = body[index + 1]
		_segment(canvas, foot - Vector2(1, 0), foot + Vector2(1, 0), color, far)
	_segment(canvas, body[1], body[7], color, far)
	_segment(canvas, body[7], body[8], color, far)
	_segment(canvas, body[1], body[2], color, rim)
	_segment(canvas, body[1] + Vector2(1, 0), body[2] + Vector2(1, 0), color, far)
	_segment(canvas, body[1], body[9], color, rim)
	_segment(canvas, body[9], body[10], color, rim)
	var head := Vector2i(body[0].round())
	for row in range(-2, 3):
		var radius := 1 if absi(row) == 2 else 2
		for column in range(-radius, radius + 1):
			_pixel(canvas, head + Vector2i(column, row), rim if row == -2 else color)
	canvas.draw_set_transform(feet, tilt, Vector2(f.facing, 1.0))
	if not gear.is_empty():
		var in_aim: bool = f.aiming and f.has_gun()
		var forward := Vector2(cos(f.elevation), sin(f.elevation)) if in_aim else Vector2(1.0, 0.13)
		var hand: Vector2 = body[10] * PIXEL_SCALE
		var rear := hand - forward * 4.0
		var tip := hand + forward * (float(gear.size) * 0.68)
		if in_aim:
			rear = AIM_ORIGIN + forward * (10.0 if gear.size <= 9 else 3.0)
			tip = AIM_ORIGIN + forward * muzzle_length(gear)
		canvas.draw_line(rear.round(), tip.round(), color, 3.0)
		canvas.draw_line((rear + Vector2(0, -1)).round(), (tip + Vector2(0, -1)).round(), Color(gear.color).darkened(0.45))
	canvas.draw_set_transform(Vector2.ZERO)
