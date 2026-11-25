extends Node2D

const STAGE = preload("res://assets/deposito.png")
const SPRITES = preload("res://assets/luchadores.png")
const WIDTH := 480.0
const FLOOR := 237.0
const PLATFORMS := [Vector3(38, 142, 199), Vector3(174, 306, 155), Vector3(338, 442, 195), Vector3(0, 480, FLOOR)]
const LADDERS := [Vector3(53, 199, FLOOR), Vector3(295, 155, FLOOR), Vector3(425, 195, FLOOR)]
const DOUBLE_TAP := 0.27
const SLIDE_TIME := 0.34
const BULLET_DODGE := 0.30
const MAX_ELEVATION := 1.18
const PAPER := Color("f1e8d5")
const AMBER := Color("ffbc69")
const MINT := Color("82dfbb")
const CORAL := Color("ff8279")
const INK := Color("161b24")
const MUTED := Color("bab1ae")
const GEAR := {
	"pistol": {"label": "PISTOLA", "capacity": 8, "damage": 15, "spread": [0.0], "range": 260.0, "cycle": 0.25, "reload": 0.54},
	"scatter": {"label": "ESCOPETA", "capacity": 4, "damage": 9, "spread": [-0.12, -0.06, 0.0, 0.06, 0.12], "range": 134.0, "cycle": 0.55, "reload": 0.74},
	"pipe": {"label": "TUBO", "capacity": 0, "damage": 25}
}

class Item:
	var kind: String
	var ammo: int
	var spare: int
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var thrown_by := -1
	var cooldown := 0.0
	var rest := true

	func _init(item_kind: String, capacity: int, location: Vector2) -> void:
		kind = item_kind
		ammo = capacity
		spare = int(capacity > 0)
		position = location

	func is_gun() -> bool:
		return kind != "pipe"

class Fighter:
	var team: int
	var position: Vector2
	var facing: int
	var hp := 100
	var velocity := Vector2.ZERO
	var push := 0.0
	var grounded := true
	var aiming := false
	var elevation := 0.0
	var crouched := false
	var climbing := false
	var sprint := 0
	var slide := 0.0
	var slide_side := 1
	var cooldown := 0.0
	var reload := 0.0
	var strike := 0.0
	var flash := 0.0
	var dodge := 0.0
	var stagger := 0.0
	var think := 0.0
	var intent := {}
	var aim_time := 0.0
	var item: Item

	func _init(side: int, location: Vector2, direction: int) -> void:
		team = side
		position = location
		facing = direction

	func direction() -> Vector2:
		return Vector2(facing * cos(elevation), sin(elevation))

	func has_gun() -> bool:
		return item != null and item.is_gun()

var fighters: Array[Fighter] = []
var items: Array[Item] = []
var bullets: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var spawn_points: Array[Dictionary] = []
var keys := {}
var pressed := {}
var last_tap := {}
var wins := [0, 0]
var round_number := 1
var clock := 60.0
var elapsed := 0.0
var state := "title"
var panel_title := "ÚLTIMO TURNO"
var panel_copy := "Gana dos rondas contra Vanta."
var banner := "DEPÓSITO 07"
var muted := false
var sounds := {}
var voices: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_build_sounds()
	_setup_round()
	get_window().focus_exited.connect(_on_focus_exited)

func _on_focus_exited() -> void:
	keys.clear()
	pressed.clear()
	last_tap.clear()
	if state == "playing":
		_pause()

func _setup_round() -> void:
	fighters.assign([Fighter.new(0, Vector2(77, 199), 1), Fighter.new(1, Vector2(404, 195), -1)])
	items.clear()
	bullets.clear()
	sparks.clear()
	spawn_points.assign([
		{"kind": "pistol", "location": Vector2(113, 199)},
		{"kind": "pistol", "location": Vector2(367, 195)},
		{"kind": "scatter", "location": Vector2(240, 155)},
		{"kind": "pipe", "location": Vector2(164, FLOOR)},
		{"kind": "pipe", "location": Vector2(328, FLOOR)}
	])
	for point in spawn_points:
		point.item = _new_item(point.kind, point.location)
		point.wait = 0.0
	clock = 60.0
	queue_redraw()

func _new_item(kind: String, location: Vector2) -> Item:
	var item := Item.new(kind, GEAR[kind].capacity, location)
	items.append(item)
	return item

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if not event.pressed:
		keys.erase(key)
		return
	if key == KEY_M:
		muted = not muted
		if muted:
			for voice in voices:
				voice.stop()
		queue_redraw()
		return
	if key == KEY_ESCAPE:
		if state == "playing":
			_pause()
		elif state == "paused":
			_continue()
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		if state != "playing":
			_continue()
		return
	if state != "playing" or keys.has(key):
		return
	keys[key] = true
	pressed[key] = true
	var player := fighters[0]
	if keys.has(KEY_N):
		if key == KEY_A or key == KEY_D:
			player.facing = -1 if key == KEY_A else 1
		if key == KEY_S and _double_tap(KEY_S):
			player.facing = -1
	elif key == KEY_A or key == KEY_D:
		if _double_tap(key):
			player.sprint = -1 if key == KEY_A else 1

func _double_tap(key: int) -> bool:
	var detected: bool = elapsed - last_tap.get(key, -10.0) <= DOUBLE_TAP
	if detected:
		last_tap.erase(key)
	else:
		last_tap[key] = elapsed
	return detected

func _pause() -> void:
	state = "paused"
	panel_title = "EN PAUSA"
	panel_copy = "ENTER o ESC para continuar"
	banner = "DEPÓSITO 07"
	keys.clear()
	pressed.clear()
	last_tap.clear()
	queue_redraw()

func _continue() -> void:
	if state == "title" or state == "match_end":
		wins = [0, 0]
		round_number = 1
		_setup_round()
	elif state == "round_end":
		round_number += 1
		_setup_round()
	keys.clear()
	pressed.clear()
	last_tap.clear()
	state = "playing"
	_play("pick")

func _physics_process(dt: float) -> void:
	if state == "title":
		elapsed += dt
		queue_redraw()
	if state != "playing":
		return
	elapsed += dt
	clock = maxf(0.0, clock - dt)
	var player := fighters[0]
	var rival := fighters[1]
	_step_fighter(player, rival, _player_intent(), dt)
	pressed.clear()
	_step_fighter(rival, player, _rival_intent(rival, player, dt), dt)
	_step_bullets(dt)
	_step_items(dt)
	_step_sparks(dt)
	if player.hp == 0 or rival.hp == 0 or clock == 0:
		_finish_round()
	queue_redraw()

func _player_intent() -> Dictionary:
	var aim := keys.has(KEY_N)
	return {
		"move": int(keys.has(KEY_D)) - int(keys.has(KEY_A)),
		"vertical": int(keys.has(KEY_S)) - int(keys.has(KEY_W)),
		"aim": aim, "jump": pressed.has(KEY_SPACE), "slide": pressed.has(KEY_S),
		"grab": pressed.has(KEY_E), "throw": pressed.has(KEY_Q), "reload": pressed.has(KEY_R),
		"melee": keys.has(KEY_J) or pressed.has(KEY_J), "fire": keys.has(KEY_K) or pressed.has(KEY_K)
	}

func _step_fighter(f: Fighter, target: Fighter, intent: Dictionary, dt: float) -> void:
	if f.hp == 0:
		return
	var move: int = intent.get("move", 0)
	var vertical: int = intent.get("vertical", 0)
	f.cooldown = maxf(0.0, f.cooldown - dt)
	f.slide = maxf(0.0, f.slide - dt)
	f.stagger = maxf(0.0, f.stagger - dt)
	f.strike = maxf(0.0, f.strike - dt)
	f.flash = maxf(0.0, f.flash - dt)
	f.dodge = maxf(0.0, f.dodge - dt)
	if f.reload > 0:
		f.reload = maxf(0.0, f.reload - dt)
		if f.reload == 0:
			_finish_reload(f)
	var was_aiming := f.aiming
	f.aiming = intent.get("aim", false) and f.slide == 0 and f.stagger == 0
	if f.aiming and not was_aiming:
		f.elevation = 0.0
		f.sprint = 0
		if f.team == 0:
			last_tap.erase(KEY_A)
			last_tap.erase(KEY_D)
	if f.aiming:
		if intent.has("facing"):
			f.facing = intent.facing
		f.elevation = clampf(intent.get("elevation", f.elevation + vertical * dt * 1.85), -MAX_ELEVATION, MAX_ELEVATION)
		f.aim_time += dt
	else:
		f.aim_time = 0.0
	if not f.aiming and f.slide == 0 and f.stagger == 0:
		if move != f.sprint or f.climbing:
			f.sprint = 0
		if move != 0:
			f.facing = move
		if intent.get("slide", false) and f.sprint != 0 and f.grounded:
			f.slide_side = f.facing
			f.slide = SLIDE_TIME
			f.sprint = 0
			_burst(f.position, Color("ad8c80"), 8)
			_play("slide")
	f.crouched = not f.aiming and f.slide == 0 and f.grounded and vertical > 0
	if f.stagger == 0:
		_use_item(f, target, intent)
	_move_fighter(f, intent, move, vertical, dt)

func _use_item(f: Fighter, target: Fighter, intent: Dictionary) -> void:
	if intent.get("throw", false) and f.item != null:
		_drop_item(f, true)
	elif intent.get("grab", false):
		_grab(f)
	if intent.get("reload", false):
		_start_reload(f)
	if f.cooldown > 0 or f.reload > 0 or f.slide > 0:
		return
	if f.aiming:
		if intent.get("fire", false) and f.has_gun() and f.item.ammo > 0:
			_fire(f)
	elif intent.get("melee", false):
		_melee(f, target)

func _move_fighter(f: Fighter, intent: Dictionary, move: int, vertical: int, dt: float) -> void:
	var ladder := _near_ladder(f.position)
	var jump: bool = intent.get("jump", false) and not f.aiming and f.slide == 0 and f.stagger == 0
	if f.climbing and (ladder == Vector3.ZERO or move != 0 and not f.aiming or jump or f.stagger > 0):
		f.climbing = false
		if jump:
			f.grounded = true
	if not f.aiming and not jump and f.stagger == 0 and f.slide == 0 and ladder != Vector3.ZERO and vertical != 0:
		if f.climbing or vertical < 0 and f.position.y > ladder.y or vertical > 0 and f.position.y < ladder.z:
			f.climbing = true
			f.crouched = false
			f.sprint = 0
	if f.climbing:
		f.position.x = ladder.x
		f.velocity = Vector2.ZERO
		if not f.aiming:
			f.position.y = clampf(f.position.y + vertical * 74.0 * dt, ladder.y, ladder.z)
			if f.position.y == ladder.y and vertical < 0 or f.position.y == ladder.z and vertical > 0:
				f.climbing = false
				f.grounded = true
		return
	if jump and f.grounded:
		f.velocity.y = -287.0
		f.grounded = false
		_play("jump")
		_burst(f.position, Color("b49483"), 5)
	var speed := 119.0 if f.team == 0 else 101.0
	if f.sprint != 0:
		speed = 182.0
	if f.crouched:
		speed *= 0.45
	var horizontal := 0.0 if f.aiming or f.stagger > 0 else move * speed
	if f.slide > 0:
		horizontal = f.slide_side * lerpf(116.0, 240.0, f.slide / SLIDE_TIME)
	f.velocity.x = horizontal + f.push
	f.push = move_toward(f.push, 0.0, 590.0 * dt)
	f.position.x = clampf(f.position.x + f.velocity.x * dt, 9.0, WIDTH - 9.0)
	var old_y := f.position.y
	f.velocity.y += 615.0 * dt
	f.position.y += f.velocity.y * dt
	f.grounded = false
	if f.velocity.y >= 0.0:
		var landing := _landing_y(f.position, old_y)
		if landing >= 0:
			f.position.y = landing
			f.velocity.y = 0.0
			f.grounded = true

func _near_ladder(position: Vector2) -> Vector3:
	for ladder in LADDERS:
		if absf(position.x - ladder.x) <= 7.0 and position.y >= ladder.y - 1.0 and position.y <= ladder.z:
			return ladder
	return Vector3.ZERO

func _landing_y(position: Vector2, old_y: float) -> float:
	for platform in PLATFORMS:
		if position.x >= platform.x and position.x <= platform.y and old_y <= platform.z and position.y >= platform.z:
			return platform.z
	return -1.0

func _rival_intent(rival: Fighter, player: Fighter, dt: float) -> Dictionary:
	rival.think -= dt
	if rival.think > 0:
		return rival.intent
	rival.think = randf_range(0.09, 0.16)
	var offset := player.position - rival.position
	var distance := absf(offset.x)
	var toward := -1 if offset.x < 0 else 1
	var intent := {"move": toward}
	var melee_range := 27.0 if rival.item != null and not rival.has_gun() else 20.0
	if distance <= melee_range and absf(offset.y) < 13.0:
		rival.facing = toward
		intent = {"move": 0, "melee": true}
	elif rival.reload > 0:
		intent = {"move": -toward if distance < 70.0 else 0}
	elif rival.has_gun() and rival.item.ammo == 0 and rival.item.spare > 0:
		intent = {"move": -toward if distance < 70.0 else 0, "reload": true}
	elif (not rival.has_gun() or rival.item.ammo == 0) and distance > 35.0:
		var pickup := _rival_pickup(rival)
		if pickup != null:
			intent.move = signi(int(pickup.position.x - rival.position.x))
			intent.grab = _near_item(rival) == pickup
			if intent.grab:
				intent.move = 0
	if not intent.get("grab", false) and not intent.get("reload", false) and not intent.get("melee", false) and rival.reload == 0:
		if rival.has_gun() and rival.item.ammo > 0 and distance < float(GEAR[rival.item.kind].range) * 0.76 and absf(offset.y) < minf(90.0, distance * 1.6):
			intent = {"aim": true, "facing": toward, "elevation": atan2(offset.y, distance) + randf_range(-0.09, 0.09), "fire": rival.aim_time >= 0.26 and randf() < 0.58}
		elif absf(offset.y) > 15.0 and distance < 120.0:
			if offset.y < 0 and rival.grounded:
				if offset.y < -64.0:
					var step_x := 116.0 if rival.position.x < WIDTH / 2 else 364.0
					intent.move = -1 if step_x < rival.position.x else 1
					intent.jump = absf(step_x - rival.position.x) < 47.0
				else:
					intent.jump = distance < 100.0
			elif offset.y > 0 and distance < 20.0:
				for platform in PLATFORMS:
					if rival.position.y == platform.z and rival.position.x >= platform.x and rival.position.x <= platform.y:
						intent.move = -1 if rival.position.x < (platform.x + platform.y) * 0.5 else 1
						break
	rival.intent = intent
	return intent

func _rival_pickup(rival: Fighter) -> Item:
	for item in items:
		if item.rest and item.is_gun() and item.ammo + item.spare > 0 and absf(item.position.x - rival.position.x) < 66.0 and absf(item.position.y - rival.position.y) < 10.0:
			return item
	return null

func _near_item(fighter: Fighter) -> Item:
	var closest: Item
	var distance := 17.0
	for item in items:
		var dx := absf(item.position.x - fighter.position.x)
		if item.rest and item.cooldown == 0 and dx < distance and absf(item.position.y - fighter.position.y) < 13.0:
			closest = item
			distance = dx
	return closest

func _grab(fighter: Fighter) -> void:
	var item := _near_item(fighter)
	if item == null:
		return
	if fighter.item != null:
		_drop_item(fighter, false)
	items.erase(item)
	fighter.item = item
	_burst(item.position - Vector2(0, 7), AMBER, 6)
	_play("pick")

func _drop_item(fighter: Fighter, thrown: bool) -> void:
	var item := fighter.item
	var side := fighter.facing
	item.position = Vector2(clampf(fighter.position.x + side * 10.0, 5.0, WIDTH - 5.0), fighter.position.y - 12.0)
	item.velocity = Vector2(side * 48.0, -40.0)
	item.thrown_by = fighter.team if thrown else -1
	if thrown:
		item.velocity = fighter.direction() * 240.0 if fighter.aiming else Vector2(side * 240.0, -110.0)
		_play("throw")
	item.rest = false
	item.cooldown = 0.18
	items.append(item)
	fighter.item = null
	fighter.reload = 0.0

func _start_reload(fighter: Fighter) -> void:
	if fighter.has_gun() and fighter.item.spare > 0 and fighter.reload == 0.0 and fighter.slide == 0.0:
		fighter.reload = GEAR[fighter.item.kind].reload
		_play("reload")

func _finish_reload(fighter: Fighter) -> void:
	if fighter.has_gun() and fighter.item.spare > 0:
		fighter.item.spare -= 1
		fighter.item.ammo = GEAR[fighter.item.kind].capacity
		_play("pick")

func _muzzle(fighter: Fighter) -> Vector2:
	return fighter.position - Vector2(0.0, 15.0) + fighter.direction() * 13.0

func _fire(fighter: Fighter) -> void:
	var weapon: Dictionary = GEAR[fighter.item.kind]
	fighter.cooldown = weapon.cycle if fighter.team == 0 else weapon.cycle + 0.16
	fighter.item.ammo -= 1
	var origin := _muzzle(fighter)
	for spread in weapon.spread:
		var direction := fighter.direction().rotated(spread)
		var damage: int = weapon.damage if fighter.team == 0 else ceili(weapon.damage * 0.65)
		bullets.append({"position": origin, "direction": direction, "left": weapon.range, "team": fighter.team, "damage": damage, "checked": false})
	_burst(origin, AMBER, 6)
	_play("shot")

func _melee(fighter: Fighter, target: Fighter) -> void:
	var pipe := fighter.item != null and not fighter.has_gun()
	var distance := (target.position.x - fighter.position.x) * fighter.facing
	var reach := 28.0 if pipe else 20.0
	var damage: int = GEAR.pipe.damage if pipe else 14
	fighter.cooldown = 0.43 if pipe else 0.31
	fighter.strike = 0.15
	if distance >= -4.0 and distance <= reach and absf(target.position.y - fighter.position.y) < 14.0:
		if _hit(target, damage if fighter.team == 0 else damage - 3, fighter.facing, "melee"):
			_play("punch")

func _hit(target: Fighter, damage: int, direction: int, kind: String) -> bool:
	if target.hp == 0:
		return false
	if target.slide > 0 and (kind == "melee" or kind == "bullet" and randf() < BULLET_DODGE):
		target.dodge = 0.19
		_burst(target.position - Vector2(0, 9), MINT, 5)
		return false
	target.hp = maxi(0, target.hp - damage)
	target.flash = 0.14
	target.stagger = maxf(target.stagger, 0.07 if kind == "bullet" else 0.14)
	target.push = direction * (48.0 if kind == "bullet" else 108.0)
	_burst(target.position - Vector2(0, 13), PAPER, 5)
	if target.hp == 0 and target.item != null:
		_drop_item(target, false)
	return true

func _hurtbox(fighter: Fighter) -> Rect2:
	var tall := 14.0 if fighter.crouched else 24.0
	return Rect2(fighter.position - Vector2(6, tall), Vector2(12, tall - 2))

func _step_bullets(dt: float) -> void:
	for index in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[index]
		var last: Vector2 = bullet.position
		var travel := minf(405.0 * dt, bullet.left)
		bullet.position += bullet.direction * travel
		bullet.left -= travel
		var target := fighters[1 - int(bullet.team)]
		if not bullet.checked and target.hp > 0 and _crosses(last, bullet.position, _hurtbox(target)):
			bullet.checked = true
			if _hit(target, bullet.damage, 1 if bullet.direction.x > 0 else -1, "bullet"):
				bullets.remove_at(index)
				continue
		if bullet.left <= 0 or not Rect2(0, 0, WIDTH, FLOOR).has_point(bullet.position):
			bullets.remove_at(index)

func _crosses(start: Vector2, end: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(start) or bounds.has_point(end):
		return true
	var corner := bounds.position
	var across := Vector2(bounds.end.x, corner.y)
	var down := Vector2(corner.x, bounds.end.y)
	return Geometry2D.segment_intersects_segment(start, end, corner, across) != null or Geometry2D.segment_intersects_segment(start, end, across, bounds.end) != null or Geometry2D.segment_intersects_segment(start, end, bounds.end, down) != null or Geometry2D.segment_intersects_segment(start, end, down, corner) != null

func _step_items(dt: float) -> void:
	for index in items.size():
		var item := items[index]
		item.cooldown = maxf(0, item.cooldown - dt)
		if item.rest:
			continue
		var last := item.position
		item.velocity.y += 570.0 * dt
		item.position += item.velocity * dt
		if item.thrown_by >= 0:
			var target := fighters[1 - item.thrown_by]
			if _crosses(last, item.position, _hurtbox(target)):
				_hit(target, 20 if item.is_gun() else 24, 1 if item.velocity.x > 0 else -1, "throw")
				item.velocity.x *= -0.18
				item.velocity.y = -75.0
				item.thrown_by = -1
				_play("punch")
		if item.position.x < 5.0 or item.position.x > WIDTH - 5.0:
			item.position.x = clampf(item.position.x, 5.0, WIDTH - 5.0)
			item.velocity.x *= -0.25
		if item.velocity.y < 0:
			continue
		var landing := _landing_y(item.position, last.y)
		if landing >= 0:
			item.position.y = landing
			item.rest = true
			item.thrown_by = -1
	for point in spawn_points:
		if items.has(point.item) and point.item.position.distance_to(point.location) < 10.0:
			point.wait = 0.0
		else:
			point.wait += dt
			if point.wait >= 10.0:
				point.item = _new_item(point.kind, point.location)
				point.wait = 0.0

func _burst(position: Vector2, color: Color, count: int) -> void:
	for i in count:
		sparks.append({"position": position, "velocity": Vector2(randf_range(-78, 78), randf_range(-90, -23)), "life": randf_range(0.12, 0.34), "color": color})

func _step_sparks(dt: float) -> void:
	for index in range(sparks.size() - 1, -1, -1):
		var spark := sparks[index]
		spark.life -= dt
		if spark.life <= 0:
			sparks.remove_at(index)
			continue
		spark.position += spark.velocity * dt
		spark.velocity += Vector2(0, 260) * dt

func _finish_round() -> void:
	var winner := -1
	if fighters[0].hp != fighters[1].hp:
		winner = 0 if fighters[0].hp > fighters[1].hp else 1
		wins[winner] += 1
	var score := "%d–%d" % [wins[0], wins[1]]
	banner = "RONDA %d  ·  %s" % [round_number, score]
	state = "round_end"
	panel_title = "EMPATE" if winner < 0 else ["RONDA GANADA", "RONDA PERDIDA"][winner]
	panel_copy = "ENTER para la siguiente ronda"
	if wins.has(2):
		state = "match_end"
		banner = "MARCADOR  " + score
		panel_title = "¡VICTORIA!" if winner == 0 else "DERROTA"
		panel_copy = "ENTER para la revancha"
	_play("win")

func _draw() -> void:
	draw_texture(STAGE, Vector2.ZERO)
	_draw_ladders()
	for item in items:
		_draw_item(item)
	for bullet in bullets:
		var p: Vector2 = bullet.position
		draw_line(p.round(), (p - bullet.direction * 5.0).round(), AMBER, 2.0)
		draw_rect(Rect2(p.round(), Vector2(2, 1)), PAPER)
	for fighter in fighters:
		_draw_fighter(fighter)
	for spark in sparks:
		draw_rect(Rect2(spark.position.round(), Vector2(2, 1)), spark.color)
	if state == "playing" and not fighters.is_empty():
		var near := _near_item(fighters[0])
		if near != null:
			var y := near.position.y - 22.0
			draw_rect(Rect2(near.position.x - 10, y - 8, 20, 12), INK)
			_text("[E]", Vector2(near.position.x, y + 1), 9, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_hud()
	if state != "playing":
		_draw_panel()
	_draw_controls()

func _draw_ladders() -> void:
	for ladder in LADDERS:
		var top: float = ladder.y + 3.0
		var bottom: float = ladder.z
		for side in [-5, 4]:
			draw_rect(Rect2(ladder.x + side, top, 2, bottom - top), Color("2b2933"))
			draw_rect(Rect2(ladder.x + side, top, 1, bottom - top), Color("86655d"))
		for y in range(int(top) + 4, int(bottom), 6):
			draw_rect(Rect2(ladder.x - 4.0, y, 9, 2), Color("997263"))

func _draw_item(item: Item) -> void:
	var position := item.position.round()
	if item.rest:
		draw_rect(Rect2(position.x - 7, position.y - 1, 14, 1), INK)
		position.y -= 7.0 + roundf(sin(elapsed * 4.0 + position.x) * 2.0)
	var long := 12 if item.kind != "pistol" else 8
	var angle := 0.0 if item.rest else snappedf(item.velocity.angle(), PI / 12)
	draw_set_transform(position, angle)
	draw_rect(Rect2(-long / 2.0 - 1, -2, long + 2, 5), Color("211d28"))
	draw_rect(Rect2(-long / 2.0, -1, long, 2), MINT if item.kind == "pipe" else AMBER)
	if item.is_gun():
		draw_rect(Rect2(-long / 2.0 + 1, 1, 3, 3), Color("b47b59"))
	draw_set_transform(Vector2.ZERO)

func _draw_fighter(f: Fighter) -> void:
	var position := f.position.round()
	var pose := 0
	if f.strike > 0:
		pose = 4
	elif not f.grounded or f.climbing:
		pose = 3
	elif f.has_gun() and not f.aiming:
		pose = 5 if f.item.kind == "pistol" else 6
	elif absf(f.velocity.x) > 1.0:
		var stride := 20.0 if f.sprint != 0 else 11.0
		pose = 1 + int(elapsed * stride) % 2
	var scale_y := 1.0
	if f.slide > 0:
		scale_y = 0.44
	elif f.crouched:
		scale_y = 0.65
	var tilt := 0.0 if f.hp > 0 else -f.facing * PI / 2.0
	if f.hp == 0:
		position.y -= 4.0
		scale_y = 1.0
	if f.grounded:
		draw_rect(Rect2(position - Vector2(8, 1), Vector2(16, 1)), Color("252731"))
	draw_set_transform(position, tilt, Vector2(f.facing, scale_y))
	var tint := Color(1.0, 0.57, 0.50) if f.flash > 0 and int(f.flash * 100.0) % 2 == 0 else Color.WHITE
	draw_texture_rect_region(SPRITES, Rect2(-18, -28, 36, 32), Rect2(pose * 36, f.team * 32, 36, 32), tint)
	if f.item != null and f.item.kind == "pipe":
		var length := 16 if f.strike > 0 else 9
		draw_rect(Rect2(8, -15, length, 3), Color("222a38"))
		draw_rect(Rect2(9, -15, length - 1, 1), Color("9cc5b1"))
	draw_set_transform(Vector2.ZERO)
	if f.aiming and f.has_gun():
		_draw_aim(f)
	if f.dodge > 0:
		_text("ESQUIVA", position - Vector2(0, 22), 8, MINT, HORIZONTAL_ALIGNMENT_CENTER)
	if f.reload > 0:
		var progress := 1.0 - f.reload / float(GEAR[f.item.kind].reload)
		draw_rect(Rect2(position.x - 10, position.y - 29, 20, 3), INK)
		draw_rect(Rect2(position.x - 9, position.y - 28, roundf(progress * 18.0), 1), AMBER)

func _draw_aim(f: Fighter) -> void:
	var dir := f.direction()
	var origin := (f.position - Vector2(0, 15)).round()
	var muzzle := _muzzle(f).round()
	draw_line(origin, muzzle, Color("20242f"), 4.0)
	draw_line((origin + dir * 5).round(), muzzle, Color("c6b9ac"), 2.0)
	var color := AMBER if f.team == 0 else CORAL
	for i in range(20, 71, 6):
		var mark := (origin + dir * i).round()
		draw_rect(Rect2(mark, Vector2.ONE), Color(color, 0.60))
	var cursor := (origin + dir * 75.0).round()
	draw_line(cursor - Vector2(3, 0), cursor + Vector2(3, 0), color)
	draw_line(cursor - Vector2(0, 3), cursor + Vector2(0, 3), color)

func _draw_hud() -> void:
	if fighters.is_empty():
		return
	for f in fighters:
		var left := f.team == 0
		var x := 17.0 if left else 284.0
		var color := MINT if left else CORAL
		var aligned := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		var edge := x if left else x + 179.0
		_text("TÚ" if left else "VANTA", Vector2(edge, 20), 11, color, aligned)
		var score := "◆".repeat(wins[f.team]) + "◇".repeat(2 - wins[f.team])
		_text(score, Vector2(x + 179.0 if left else x, 20), 11, color, HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT)
		draw_rect(Rect2(x, 25, 179, 6), INK)
		draw_rect(Rect2(x, 25, 179, 6), color, false)
		var live := roundf(175.0 * f.hp / 100.0)
		draw_rect(Rect2(x + 2.0 if left else x + 177.0 - live, 27, live, 2), color)
		var label := "PUÑOS"
		if f.item != null:
			label = GEAR[f.item.kind].label
			if f.has_gun():
				label += "  %d/%d  ·  %d RESERVA" % [f.item.ammo, GEAR[f.item.kind].capacity, f.item.spare]
			if f.reload > 0:
				label = "RECARGANDO…"
		_text(label, Vector2(edge, 43), 9, PAPER, aligned)
	_text("%02d" % ceili(clock), Vector2(240, 26), 21, PAPER if clock > 10 else CORAL, HORIZONTAL_ALIGNMENT_CENTER)
	_text("RONDA %d" % round_number, Vector2(240, 41), 9, PAPER, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_panel() -> void:
	draw_rect(Rect2(0, 0, WIDTH, 270), Color(0.045, 0.05, 0.09, 0.46))
	draw_rect(Rect2(109, 84, 268, 109), Color(0.035, 0.04, 0.07, 0.70))
	draw_rect(Rect2(105, 80, 270, 110), Color("8b6c5b"))
	draw_rect(Rect2(106, 82, 268, 107), INK)
	draw_rect(Rect2(106, 81, 268, 2), AMBER)
	_text(banner, Vector2(240, 102), 10, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	_text(panel_title, Vector2(240, 137), 28, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_text(panel_copy, Vector2(240, 155), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if state == "title":
		draw_rect(Rect2(177, 163, 126, 17), AMBER)
		_text("ENTER · JUGAR", Vector2(240, 175), 10, INK, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_controls() -> void:
	draw_rect(Rect2(0, 270, WIDTH, 38), Color("191f28"))
	draw_rect(Rect2(0, 270, WIDTH, 1), Color("56464b"))
	_text("WASD Mover  ·  ESP Salto  ·  A A / D D Correr  ·  S Deslizar al correr", Vector2(240, 281), 9, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_text("E Coger  ·  Q Lanzar  ·  R Recargar  ·  J Golpe  ·  N + K Disparo", Vector2(240, 292), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var sound := "M Sonido: sí" if not muted else "M Sonido: no"
	_text("Con N: W/S Mira  ·  A/D (S S izq.) Lado  ·  ESC Pausa  ·  " + sound, Vector2(240, 303), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _text(value: String, position: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	var length := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := position.x
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x -= length / 2.0
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= length
	draw_string(font, Vector2(roundf(x), position.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _build_sounds() -> void:
	for i in 5:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	var effects := {
		"pick": Vector3(330, 700, 0.11), "jump": Vector3(185, 340, 0.10), "slide": Vector3(103, 47, 0.15),
		"throw": Vector3(235, 100, 0.12), "shot": Vector3(120, 35, 0.14), "punch": Vector3(135, 56, 0.10),
		"win": Vector3(300, 610, 0.24), "reload": Vector3(145, 191, 0.12)
	}
	for sound in effects:
		var effect: Vector3 = effects[sound]
		var count := int(22050.0 * effect.z)
		var samples := PackedByteArray()
		samples.resize(count * 2)
		var phase := 0.0
		for i in count:
			var p := float(i) / count
			phase += TAU * lerpf(effect.x, effect.y, p) / 22050.0
			var wave := sin(phase) if sound == "win" else signf(sin(phase)) * 0.54 + sin(phase * 0.7) * 0.46
			var envelope := minf(p * 75, 1.0) * pow(1.0 - p, 2.0)
			samples.encode_s16(i * 2, int(wave * envelope * 4300.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = samples
		sounds[sound] = stream

func _play(kind: String) -> void:
	if muted:
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[kind]
			voice.play()
			return
