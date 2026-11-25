extends RefCounted

const AIM_ORIGIN := Vector2(0, -21)

const IDLE := [
	Vector2(0, -30), Vector2(-1, -16), Vector2(-1, -24),
	Vector2(-4, -8), Vector2(-5, -1), Vector2(3, -8), Vector2(4, -1),
	Vector2(-5, -18), Vector2(0, -22), Vector2(5, -19), Vector2(8, -24),
]
const CROUCH := [
	Vector2(4, -20), Vector2(-3, -8), Vector2(1, -15),
	Vector2(-5, -5), Vector2(-7, -1), Vector2(5, -5), Vector2(4, -1),
	Vector2(-4, -10), Vector2(1, -13), Vector2(7, -12), Vector2(9, -15),
]
const AIR := [
	Vector2(2, -30), Vector2(-1, -16), Vector2(0, -24),
	Vector2(-8, -10), Vector2(-7, -5), Vector2(5, -12), Vector2(2, -6),
	Vector2(-7, -20), Vector2(-6, -14), Vector2(6, -24), Vector2(9, -29),
]
const SLIDE := [
	Vector2(0, -13), Vector2(-5, -5), Vector2(-2, -9),
	Vector2(-11, -4), Vector2(-12, -1), Vector2(5, -3), Vector2(13, -1),
	Vector2(-8, -10), Vector2(-10, -7), Vector2(4, -8), Vector2(8, -6),
]
const GUARD := [
	Vector2(-1, -25), Vector2(-3, -12), Vector2(-2, -20),
	Vector2(-5, -7), Vector2(-6, -1), Vector2(4, -7), Vector2(4, -1),
	Vector2(2, -21), Vector2(2, -27), Vector2(7, -22), Vector2(5, -29),
]
const HIT := [
	Vector2(-5, -26), Vector2(0, -15), Vector2(-3, -22),
	Vector2(-5, -7), Vector2(-5, -1), Vector2(4, -7), Vector2(6, -1),
	Vector2(-7, -18), Vector2(-9, -17), Vector2(2, -18), Vector2(6, -16),
]
const EXHAUST := [
	Vector2(4, -24), Vector2(-4, -12), Vector2(1, -19),
	Vector2(-6, -7), Vector2(-6, -1), Vector2(5, -7), Vector2(6, -1),
	Vector2(-4, -13), Vector2(-4, -8), Vector2(6, -13), Vector2(7, -8),
]
const PICKUP := [
	Vector2(7, -19), Vector2(-4, -9), Vector2(2, -14),
	Vector2(-6, -6), Vector2(-7, -1), Vector2(5, -5), Vector2(5, -1),
	Vector2(0, -10), Vector2(2, -8), Vector2(8, -7), Vector2(11, -2),
]
const CLIMB := [
	Vector2(1, -30), Vector2(-1, -15), Vector2(0, -24),
	Vector2(-4, -8), Vector2(-4, -1), Vector2(4, -9), Vector2(5, -2),
	Vector2(-6, -24), Vector2(-5, -30), Vector2(5, -25), Vector2(5, -34),
]
const WINDUP := [
	Vector2(-2, -29), Vector2(-2, -16), Vector2(-2, -23),
	Vector2(-5, -8), Vector2(-7, -1), Vector2(4, -8), Vector2(6, -1),
	Vector2(-5, -19), Vector2(1, -25), Vector2(-5, -20), Vector2(-7, -24),
]
const PUNCH := [
	Vector2(4, -28), Vector2(0, -15), Vector2(2, -22),
	Vector2(-4, -8), Vector2(-8, -1), Vector2(7, -7), Vector2(9, -1),
	Vector2(-2, -18), Vector2(2, -20), Vector2(11, -23), Vector2(20, -22),
]

static func _blend(pose: Array, target: Array, amount: float) -> void:
	for index in pose.size():
		pose[index] = pose[index].lerp(target[index], amount)

static func _gait(pose: Array, distance: float, speed: float, crouch: float) -> void:
	var run := smoothstep(112.0, 171.0, speed) * (1.0 - crouch)
	var strength := smoothstep(4.0, 90.0, speed)
	var stride := distance * TAU / 40.0
	var foot := cos(stride)
	var lift := sin(stride)
	var reach := lerpf(6.0, 11.0, run) * strength
	var height := lerpf(4.0, 8.0, run) * strength
	pose[4] += Vector2(foot * reach, -maxf(lift, 0.0) * height)
	pose[6] += Vector2(-foot * reach, -maxf(-lift, 0.0) * height)
	pose[3] += Vector2(foot * reach * 0.65 + run * 3.0, -maxf(lift, 0.0) * height * 0.65)
	pose[5] += Vector2(-foot * reach * 0.65 + run * 3.0, -maxf(-lift, 0.0) * height * 0.65)
	var bob := -absf(lift) * strength * (1.4 + run)
	pose[0] += Vector2(run * 4.0, bob)
	pose[1] += Vector2(run * 1.5, bob)
	pose[2] += Vector2(run * 3.0, bob)
	pose[7] += Vector2(-foot * reach * 0.35, absf(lift) * 2.0)
	pose[8] += Vector2(-foot * reach * 0.52, 4.0 * strength)
	pose[9] += Vector2(foot * reach * 0.38, absf(lift) * 2.0)
	pose[10] += Vector2(foot * reach * 0.65, 4.0 * strength)

static func muzzle_length(gear: Dictionary) -> float:
	return 22.0 if gear.size <= 9 else 15.0 + float(gear.size) * 0.66

static func _pose(f, gear: Dictionary) -> Array:
	var pose := IDLE.duplicate()
	var breathing := sin(f.motion_clock * 4.0) * 0.65
	for i in [0, 2, 7, 8, 9, 10]:
		pose[i].y += breathing
	_blend(pose, CROUCH, maxf(f.visual_crouch, sin(f.landing / 0.18 * PI) * 0.52))
	_gait(pose, f.stride_distance, absf(f.move_speed), f.visual_crouch)
	var air := AIR.duplicate()
	var fall := smoothstep(-160.0, 220.0, f.velocity.y)
	air[4] += Vector2(-2.0, 4.0) * fall
	air[6] += Vector2(5.0, 5.0) * fall
	air[10] += Vector2(2.0, 8.0) * fall
	_blend(pose, air, f.visual_air)
	if f.climbing:
		var climb := CLIMB.duplicate()
		var step := cos(f.position.y * TAU / 20.0) * 3.0
		for i in [3, 4, 7, 8]:
			climb[i].y += step
		for i in [5, 6, 9, 10]:
			climb[i].y -= step
		pose = climb
	if f.slide > 0.0:
		var slide_progress: float = 1.0 - f.slide / 0.34
		_blend(pose, SLIDE, smoothstep(0.0, 0.17, slide_progress) * (1.0 - smoothstep(0.72, 1.0, slide_progress)))
	_blend(pose, GUARD, f.visual_guard)
	if f.pickup > 0.0:
		_blend(pose, PICKUP, sin((1.0 - f.pickup / 0.28) * PI))
	if f.strike > 0.0:
		var phase: float = 1.0 - f.strike / 0.32
		_blend(pose, WINDUP, smoothstep(0.0, 0.16, phase) * (1.0 - smoothstep(0.16, 0.40, phase)))
		_blend(pose, PUNCH, smoothstep(0.10, 0.31, phase) * (1.0 - smoothstep(0.43, 1.0, phase)))
	if f.stagger > 0.0:
		_blend(pose, HIT, smoothstep(0.0, 0.17, f.stagger))
	if f.exhausted > 0.0 or f.knocked > 0.0:
		_blend(pose, EXHAUST, smoothstep(0.0, 0.2, maxf(f.exhausted, f.knocked)))
	if (f.aiming or f.recoil > 0.09) and f.has_gun() and not gear.is_empty():
		var direction := Vector2(cos(f.elevation), sin(f.elevation))
		var down := Vector2(-direction.y, direction.x)
		var pistol: bool = gear.size <= 9
		var grip := 16.0 if pistol else 9.0
		var support := 15.0 if pistol else muzzle_length(gear) - 9.0
		pose[7] = AIM_ORIGIN + direction * (support * 0.55) + down * 3.0
		pose[8] = AIM_ORIGIN + direction * support + down * 2.0
		pose[9] = AIM_ORIGIN + direction * (grip * 0.5) + down * (2.0 if pistol else 6.0)
		pose[10] = AIM_ORIGIN + direction * grip + down * 2.0
		for index in [7, 8, 9, 10]:
			pose[index] -= direction * (f.recoil * 10.0)
	elif f.item != null and not (f.blocking or f.strike > 0.0 or f.pickup > 0.0 or f.climbing or f.locked()):
		var reload_mix: float = clampf(f.reload * 5.0, 0.0, 1.0)
		pose[8] = pose[8].lerp(Vector2(3, -16), 0.7)
		pose[10] = pose[10].lerp(Vector2(7, -17), 0.65).lerp(Vector2(3, -17), reload_mix)
	return pose

static func _shape(canvas: Node2D, points: Array, paint: Color) -> void:
	var vertices := PackedVector2Array()
	for point: Vector2 in points:
		vertices.append(point.round())
	canvas.draw_colored_polygon(vertices, paint)

static func _limb(canvas: Node2D, start: Vector2, joint: Vector2, end: Vector2, fill: Color, edge: Color, width: float) -> void:
	canvas.draw_line(start.round(), joint.round(), fill, width)
	canvas.draw_line(joint.round(), end.round(), fill, width - 1.0)
	canvas.draw_rect(Rect2(joint.round() - Vector2.ONE, Vector2(3, 3)), fill)
	canvas.draw_line((start + Vector2(-1, -1)).round(), (joint + Vector2(-1, -1)).round(), edge)

static func paint(canvas: Node2D, f, gear: Dictionary) -> void:
	var pose := _pose(f, gear)
	var progress: float = 1.5 - f.knocked
	var fall := smoothstep(0.0, 0.24, progress) * smoothstep(0.0, 0.23, f.knocked)
	if f.hp == 0:
		fall = 1.0
	var tilt: float = float(f.knock_side) * fall * 1.47
	var position: Vector2 = f.position.round() - Vector2(0, 3.0 * fall)
	var dark := Color("000001")
	var shade := Color("030307") if f.team == 0 else Color("050205")
	var seam := Color("101017") if f.team == 0 else Color("180b12")
	var rim := Color("9b6378") if f.team == 0 else Color("be766c")
	var face := Color("110910") if f.team == 0 else Color("170a0e")
	var accent := Color("5e9188") if f.team == 0 else Color("a55c58")
	if f.flash > 0.0:
		rim = rim.lerp(Color("f6b090"), f.flash / 0.14)
	if f.grounded:
		canvas.draw_rect(Rect2(f.position.round() - Vector2(9 + 6 * fall, 1), Vector2(18 + 12 * fall, 2)), Color("090b13"))
	canvas.draw_set_transform(position, tilt, Vector2(f.facing, 1.0))
	var head: Vector2 = pose[0]
	var hip: Vector2 = pose[1]
	var chest: Vector2 = pose[2]
	_limb(canvas, hip + Vector2(-2, 1), pose[3], pose[4], dark, shade, 6.0)
	_limb(canvas, chest + Vector2(-2, 0), pose[7], pose[8], dark, shade, 5.0)
	_limb(canvas, hip + Vector2(2, 1), pose[5], pose[6], shade, seam, 7.0)
	for index in [4, 6]:
		var foot: Vector2 = pose[index].round()
		canvas.draw_rect(Rect2(foot - Vector2(3, 2), Vector2(8, 3)), dark)
		canvas.draw_line(foot + Vector2(-2, -2), foot + Vector2(3, -2), seam)
	_shape(canvas, [
		chest + Vector2(-5, -2), chest + Vector2(3, -2), chest + Vector2(6, 1),
		hip + Vector2(5, 2), hip + Vector2(-4, 2), chest + Vector2(-5, 2),
	], shade)
	_shape(canvas, [chest + Vector2(-4, 0), chest + Vector2(2, -1), hip + Vector2(1, 0), hip + Vector2(-3, 0)], seam)
	canvas.draw_line((chest + Vector2(-4, -2)).round(), (hip + Vector2(-4, -1)).round(), rim)
	canvas.draw_line((hip + Vector2(-3, 0)).round(), (hip + Vector2(3, 0)).round(), dark)
	canvas.draw_rect(Rect2((chest + Vector2(-1, 1)).round(), Vector2(2, 1)), accent)
	_shape(canvas, [
		head + Vector2(-4, -2), head + Vector2(-2, -5), head + Vector2(2, -5),
		head + Vector2(4, -3), head + Vector2(4, 0), head + Vector2(5, 1),
		head + Vector2(3, 4), head + Vector2(-1, 5), head + Vector2(-4, 2),
	], dark)
	_shape(canvas, [head + Vector2(0, -2), head + Vector2(3, -2), head + Vector2(4, 1), head + Vector2(2, 4), head + Vector2(0, 3)], face)
	canvas.draw_line((head + Vector2(-2, -5)).round(), (head + Vector2(2, -5)).round(), rim)
	canvas.draw_rect(Rect2((head + Vector2(2, -1)).round(), Vector2(2, 1)), seam)
	canvas.draw_line((head + Vector2(-2, 4)).round(), (head + Vector2(2, 4)).round(), accent)
	_limb(canvas, chest + Vector2(3, 0), pose[9], pose[10], shade, rim.darkened(0.35), 5.0)
	var hand: Vector2 = pose[10].round()
	canvas.draw_rect(Rect2(hand - Vector2(1, 1), Vector2(3, 3)), face)
	canvas.draw_rect(Rect2(hand + Vector2(0, -1), Vector2(2, 1)), rim.darkened(0.38))
	if not gear.is_empty():
		var aiming: bool = (f.aiming or f.recoil > 0.09) and f.has_gun()
		var direction := Vector2(cos(f.elevation), sin(f.elevation)) if aiming else Vector2(1.0, 0.18)
		var stock := hand - direction * 3.0
		var barrel: Vector2 = hand + direction * float(gear.size) * 0.76
		if aiming:
			stock = AIM_ORIGIN + direction * (12.0 if gear.size <= 9 else 3.0)
			barrel = AIM_ORIGIN + direction * muzzle_length(gear)
			stock -= direction * (f.recoil * 10.0)
			barrel -= direction * (f.recoil * 10.0)
		var edge := Vector2(direction.y, -direction.x)
		canvas.draw_line(stock.round(), barrel.round(), dark, 3.0)
		canvas.draw_line((stock + edge).round(), (barrel + edge).round(), Color(gear.color).darkened(0.54))
	canvas.draw_set_transform(Vector2.ZERO)
