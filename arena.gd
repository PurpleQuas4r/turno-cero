extends Node2D

const ArenaBackground = preload("res://arena_background.gd")
const WIDTH := 480.0
const FLOOR := 237.0
const ROOF_LEFT := 26.0
const ROOF_RIGHT := WIDTH - ROOF_LEFT
const FALL_LIMIT := 325.0
const LAB_PLATE_WIDTH := 35.0
const LEVELS := ["HELIPUERTO", "SALA DE PRUEBAS"]
const PAUSE_OPTIONS := ["Continuar", "Cambiar nivel", "Salir del juego"]
const PLATFORM_HEIGHT := 204.0
const PLATFORMS := [
	Vector3(40, 136, PLATFORM_HEIGHT),
	Vector3(WIDTH - 136, WIDTH - 40, PLATFORM_HEIGHT),
	Vector3(ROOF_LEFT, ROOF_RIGHT, FLOOR),
]
const LADDERS := [Vector3(58, PLATFORM_HEIGHT, FLOOR), Vector3(WIDTH - 58, PLATFORM_HEIGHT, FLOOR)]
const FighterArt = preload("res://stickman_art.gd")
const Sunlight = preload("res://sunlight.gdshader")
const MAX_HEALTH := 100
const MAX_STAMINA := 100.0
const HEAVY_FACTOR := 0.2
const SPRINT_COST := 24.0
const JUMP_COST := 14.0
const GUARD_COST := 24.0
const HEAVY_DRAIN := 7.0
const STAMINA_RECOVERY := 25.0
const MELEE_INTERVAL := 0.8
const MELEE_STUN := 0.5
const MELEE_CONTACT := 0.22
const COMBO_WINDOW := 1.15
const KNOCKDOWN_TIME := 1.5
const EXHAUST_TIME := 3.0
const EXHAUST_FAST_TIME := 2.0
const RECOVERY_TAPS := 6
const RESPAWN_TIME := 8.0
const TIMER_EPSILON := 0.00001
const MOVEMENT_KEYS := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
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
const ACCURACY_VERY_LOW := 12.0
const ACCURACY_LOW := 8.0
const ACCURACY_MEDIUM := 4.0
const ACCURACY_HIGH := 2.0
const ACCURACY_VERY_HIGH := 0.6
const GEAR := {
	"9mm": {"label": "9mm", "capacity": 8, "damage": 10, "range": 240.0, "cycle": 0.45, "reload": 1.5, "spread": ACCURACY_MEDIUM, "size": 8, "color": "d8af84"},
	"glock": {"label": "GLOCK", "capacity": 12, "damage": 6, "range": 230.0, "cycle": 0.08, "reload": 2.0, "spread": ACCURACY_VERY_LOW, "size": 9, "color": "cab8a4"},
	"mp5k": {"label": "MP5K", "capacity": 20, "damage": 8, "range": 205.0, "cycle": 0.15, "reload": 1.5, "spread": ACCURACY_MEDIUM, "size": 12, "color": "c8a991"},
	"uzi": {"label": "UZI", "capacity": 32, "damage": 5, "range": 170.0, "cycle": 0.08, "reload": 2.0, "spread": ACCURACY_LOW, "size": 11, "color": "b8b4b6"},
	"akm": {"label": "AKM", "capacity": 20, "damage": 18, "range": 310.0, "cycle": 0.30, "reload": 2.5, "spread": ACCURACY_MEDIUM, "size": 15, "color": "c98969"},
	"m4": {"label": "M4", "capacity": 25, "damage": 12, "range": 330.0, "cycle": 0.22, "reload": 2.0, "spread": ACCURACY_HIGH, "size": 15, "color": "c1aaa5"},
	"awp": {"label": "AWP", "capacity": 3, "damage": 80, "range": 455.0, "cycle": 2.0, "reload": 3.5, "spread": ACCURACY_VERY_HIGH, "size": 18, "color": "aaa98d", "heavy": true},
	"rpg": {"label": "RPG", "capacity": 1, "damage": 100, "range": 350.0, "cycle": 0.0, "reload": 0.0, "spread": ACCURACY_MEDIUM, "size": 18, "color": "de9871", "heavy": true},
	"claymore": {"label": "CLAYMORE", "capacity": 1, "damage": 75, "cycle": 0.0, "reload": 0.0, "size": 10, "color": "a1b48c"},
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

	func _init(item_kind: String, location: Vector2) -> void:
		kind = item_kind
		ammo = GEAR[kind].capacity
		spare = int(GEAR[kind].reload > 0.0)
		position = location

	func is_gun() -> bool:
		return kind != "claymore"

class Fighter:
	var team: int
	var position: Vector2
	var facing: int
	var hp := MAX_HEALTH
	var velocity := Vector2.ZERO
	var stride_distance := 0.0
	var motion_clock := 0.0
	var move_speed := 0.0
	var visual_crouch := 0.0
	var visual_air := 0.0
	var visual_guard := 0.0
	var landing := 0.0
	var recoil := 0.0
	var pickup := 0.0
	var stamina := MAX_STAMINA
	var recovery_delay := 0.0
	var blocking := false
	var exhausted := 0.0
	var exhaust_taps := 0
	var knocked := 0.0
	var knock_side := 1
	var combo_hits := 0
	var combo_left := 0.0
	var melee_cooldown := 0.0
	var push := 0.0
	var grounded := true
	var aiming := false
	var aim_cancelled := false
	var active := true
	var ai := false
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
	var item: Item

	func _init(side: int, location: Vector2, direction: int) -> void:
		team = side
		position = location
		facing = direction

	func direction() -> Vector2:
		return Vector2(facing * cos(elevation), sin(elevation))

	func has_gun() -> bool:
		return item != null and item.is_gun()

	func is_heavy() -> bool:
		return item != null and GEAR[item.kind].get("heavy", false)

	func locked() -> bool:
		return exhausted > 0.0 or knocked > 0.0 or stagger > 0.0

var fighters: Array[Fighter] = []
var items: Array[Item] = []
var bullets: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var spawn_points: Array[Dictionary] = []
var keys := {}
var pressed := {}
var last_tap := {}
var wins := [0, 0]
var round_number := 1
var elapsed := 0.0
var state := "level_select"
var paused_from := "playing"
var level := 0
var menu_index := 0
var camera := Camera2D.new()
var background := ArenaBackground.new()
var hud := Node2D.new()
var lab_plates: Array[Dictionary] = []
var lighting := ShaderMaterial.new()
var panel_title := ""
var panel_copy := ""
var banner := ""
var muted := false
var sounds := {}
var voices: Array[AudioStreamPlayer] = []

func _ready() -> void:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -1
	add_child(backdrop)
	backdrop.add_child(background)
	add_child(camera)
	camera.enabled = true
	var effects := CanvasLayer.new()
	effects.layer = 1
	add_child(effects)
	var screen := ColorRect.new()
	effects.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lighting.shader = Sunlight
	screen.material = lighting
	var overlay := CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	overlay.add_child(hud)
	hud.draw.connect(_draw_overlay)
	_build_sounds()
	_setup_round()
	get_window().focus_exited.connect(_on_focus_exited)

func _redraw() -> void:
	queue_redraw()
	hud.queue_redraw()

func _clear_inputs() -> void:
	keys.clear()
	pressed.clear()
	last_tap.clear()

func _on_focus_exited() -> void:
	_clear_inputs()
	if state == "playing":
		_pause()

func _setup_round() -> void:
	if level == 1:
		fighters.assign([Fighter.new(0, Vector2(9, FLOOR), 1), Fighter.new(1, Vector2(420, FLOOR), -1)])
	else:
		fighters.assign([Fighter.new(0, Vector2(79, PLATFORM_HEIGHT), 1), Fighter.new(1, Vector2(WIDTH - 79, PLATFORM_HEIGHT), -1)])
	items.clear()
	bullets.clear()
	sparks.clear()
	mines.clear()
	spawn_points.clear()
	lab_plates.clear()
	if level == 1:
		var index := 0
		for kind: String in GEAR:
			lab_plates.append({"kind": kind, "x": 27.0 + index * 44.0, "down": false})
			index += 1
		lab_plates.append({"kind": "vanta", "x": 449.0, "down": false})
	else:
		spawn_points.assign([
			_spawn_point(Vector2(107, PLATFORM_HEIGHT), ["9mm", "mp5k"], 1.0),
			_spawn_point(Vector2(WIDTH - 107, PLATFORM_HEIGHT), ["glock", "uzi"], 1.0),
			_spawn_point(Vector2(154, FLOOR), ["akm", "awp"], 2.0),
			_spawn_point(Vector2(WIDTH - 154, FLOOR), ["m4", "rpg"], 2.0),
			_spawn_point(Vector2(WIDTH / 2, FLOOR), ["claymore"], 3.0),
		])
	_update_camera(0.0, true)
	_redraw()

func _start_level(next_level: int) -> void:
	level = next_level
	wins = [0, 0]
	round_number = 1
	background.reset(level == 1)
	lighting.set_shader_parameter("sunlight", level == 0)
	_setup_round()
	_clear_inputs()
	state = "playing"
	_play("pick")

func _spawn_point(location: Vector2, pool: Array[String], initial_delay: float) -> Dictionary:
	return {"location": location, "pool": pool, "next": 0, "wait": initial_delay, "item": null}

func _new_item(kind: String, location: Vector2) -> Item:
	var item := Item.new(kind, location)
	items.append(item)
	return item

func _input(event: InputEvent) -> void:
	if state == "level_select" or state == "paused":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var options := _menu_options()
			for index in options.size():
				if _menu_row(index).has_point(event.position):
					menu_index = index
					_accept_menu()
					break
			return
	if not event is InputEventKey or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if not event.pressed:
		if state == "playing" and key == KEY_M:
			fighters[0].aim_cancelled = false
		keys.erase(key)
		return
	if key == KEY_F1:
		muted = not muted
		if muted:
			for voice in voices:
				voice.stop()
		_redraw()
		return
	if state == "level_select" or state == "paused":
		if key == KEY_UP or key == KEY_DOWN:
			menu_index = posmod(menu_index + (1 if key == KEY_DOWN else -1), _menu_options().size())
			_redraw()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_accept_menu()
		elif key == KEY_ESCAPE and state == "paused":
			_resume()
		return
	if key == KEY_ESCAPE and state in ["playing", "round_end", "match_end"]:
		_pause()
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		if state == "round_end" or state == "match_end":
			_continue()
		return
	if state != "playing" or keys.has(key):
		return
	keys[key] = true
	pressed[key] = true
	var player := fighters[0]
	if player.exhausted > 0.0 and key in MOVEMENT_KEYS:
		player.exhaust_taps += 1
		if player.exhaust_taps == RECOVERY_TAPS:
			player.exhausted = maxf(0.0, player.exhausted - (EXHAUST_TIME - EXHAUST_FAST_TIME))
			if player.exhausted == 0.0:
				_recover_stamina(player)
	if player.locked():
		return
	if key == KEY_N and keys.has(KEY_M):
		player.aim_cancelled = true
	if (key == KEY_LEFT or key == KEY_RIGHT) and not keys.has(KEY_M):
		if _double_tap(key):
			player.sprint = -1 if key == KEY_LEFT else 1

func _menu_options() -> Array:
	return LEVELS if state == "level_select" else PAUSE_OPTIONS

func _menu_row(index: int) -> Rect2:
	return Rect2(136, 121 + index * 22, 208, 19)

func _accept_menu() -> void:
	if state == "level_select":
		_start_level(menu_index)
	elif menu_index == 0:
		_resume()
	elif menu_index == 1:
		_clear_inputs()
		state = "level_select"
		menu_index = level
	else:
		get_tree().quit()
	_redraw()

func _double_tap(key: int) -> bool:
	var detected: bool = elapsed - last_tap.get(key, -10.0) <= DOUBLE_TAP
	if detected:
		last_tap.erase(key)
	else:
		last_tap[key] = elapsed
	return detected

func _pause() -> void:
	paused_from = state
	state = "paused"
	menu_index = 0
	_clear_inputs()
	fighters[0].aiming = false
	fighters[0].aim_cancelled = false
	_redraw()

func _resume() -> void:
	_clear_inputs()
	state = paused_from
	_redraw()

func _continue() -> void:
	if state == "match_end":
		_start_level(level)
		return
	if state == "round_end":
		round_number += 1
		_setup_round()
	_clear_inputs()
	state = "playing"
	_play("pick")
	_redraw()

func _physics_process(dt: float) -> void:
	if state != "paused":
		background.advance(dt)
	if state != "playing":
		if state == "level_select":
			for fighter in fighters:
				fighter.motion_clock += dt
			_redraw()
		return
	elapsed += dt
	var player := fighters[0]
	var rival := fighters[1]
	_step_fighter(player, rival, _player_intent(), dt)
	pressed.clear()
	if rival.active:
		_step_fighter(rival, player, _lab_rival_intent(rival, player) if rival.ai else {}, dt)
	_step_bullets(dt)
	_step_items(dt)
	_step_mines(dt)
	_step_sparks(dt)
	if level == 1:
		_update_testing()
	else:
		_check_falls()
		if player.hp == 0 or rival.hp == 0:
			_finish_round()
	_update_camera(dt)
	_redraw()

func _check_falls() -> void:
	for fighter in fighters:
		if fighter.hp > 0 and fighter.position.y >= FALL_LIMIT:
			fighter.hp = 0
			fighter.active = false
			fighter.item = null
			fighter.aiming = false
			_play("throw")

func _update_camera(dt: float, instant := false) -> void:
	var combatants := fighters.filter(func(fighter: Fighter) -> bool: return fighter.active)
	if combatants.is_empty():
		return
	var first: Vector2 = combatants[0].position
	var last: Vector2 = combatants[-1].position
	var center := (first + last) * 0.5
	var span := absf(first.x - last.x)
	var vertical_span := absf(first.y - last.y)
	var desired := lerpf(1.5, 1.0, smoothstep(55.0, 400.0, span))
	var fit := minf(432.0 / maxf(span, 1.0), 176.0 / maxf(vertical_span, 1.0))
	desired = minf(desired, fit)
	var camera_zoom := desired if instant else lerpf(camera.zoom.x, desired, 1.0 - exp(-5.0 * dt))
	camera_zoom = minf(camera_zoom, fit)
	var target := Vector2(center.x, maxf(FLOOR - 79.0 / camera_zoom, center.y - 73.0 / camera_zoom))
	var next := target if instant else camera.position.lerp(target, 1.0 - exp(-7.5 * dt))
	if level == 1 and camera_zoom >= 1.0:
		var half_room := 240.0 / camera_zoom
		next.x = clampf(next.x, half_room, WIDTH - half_room)
	var half_width := 216.0 / camera_zoom
	next.x = clampf(next.x, maxf(first.x, last.x) - half_width, minf(first.x, last.x) + half_width)
	var top := minf(first.y, last.y) - 36.0
	var bottom := maxf(first.y, last.y)
	var screen_center := get_viewport_rect().size.y / 2.0
	next.y = clampf(next.y, bottom - (256.0 - screen_center) / camera_zoom, top + (screen_center - 52.0) / camera_zoom)
	camera.position = next
	camera.zoom = Vector2.ONE * camera_zoom
	camera.force_update_scroll()
	background.follow(camera.position)

func _update_testing() -> void:
	var player := fighters[0]
	var rival := fighters[1]
	if rival.hp == 0:
		rival.active = false
	if player.hp == 0:
		fighters[0] = Fighter.new(0, Vector2(9, FLOOR), 1)
		_clear_inputs()
		player = fighters[0]
	for plate in lab_plates:
		var occupied := player.grounded and absf(player.position.x - float(plate.x)) <= LAB_PLATE_WIDTH / 2.0
		if occupied and not plate.down:
			_activate_plate(plate)
		plate.down = occupied

func _activate_plate(plate: Dictionary) -> void:
	var kind: String = plate.kind
	if kind == "vanta":
		if not fighters[1].active:
			var rival := Fighter.new(1, Vector2(411, FLOOR), -1)
			rival.ai = true
			fighters[1] = rival
			_play("pick")
		return
	for item in items:
		if item.kind == kind:
			return
	for fighter in fighters:
		if fighter.active and fighter.item != null and fighter.item.kind == kind:
			return
	if kind == "claymore" and not mines.is_empty():
		return
	var side := fighters[0].facing
	var x := clampf(float(plate.x) + side * 15.0, 9.0, WIDTH - 9.0)
	_new_item(kind, Vector2(x, FLOOR))
	_play("pick")

func _lab_rival_intent(rival: Fighter, player: Fighter) -> Dictionary:
	var offset := player.position - rival.position
	var side := 1 if offset.x >= 0.0 else -1
	if absf(offset.x) <= 21.0 and absf(offset.y) < 14.0:
		if not rival.locked() and rival.strike == 0.0:
			rival.facing = side
		return {"melee": true}
	return {"move": side}

func _player_intent() -> Dictionary:
	var down := keys.has(KEY_DOWN)
	var block := down and keys.has(KEY_J)
	return {
		"move": int(keys.has(KEY_RIGHT)) - int(keys.has(KEY_LEFT)),
		"vertical": int(down) - int(keys.has(KEY_UP)),
		"block": block, "aim": keys.has(KEY_M) and not fighters[0].aim_cancelled, "jump": pressed.has(KEY_UP),
		"slide": pressed.has(KEY_DOWN), "grab": down and pressed.has(KEY_N),
		"throw": pressed.has(KEY_Q), "reload": not down and pressed.has(KEY_J),
		"melee": keys.has(KEY_N) or pressed.has(KEY_N),
		"fire": keys.has(KEY_COMMA) or pressed.has(KEY_COMMA),
	}

func _step_fighter(f: Fighter, target: Fighter, intent: Dictionary, dt: float) -> void:
	if f.hp == 0:
		return
	f.motion_clock += dt
	f.cooldown = _combat_timer(f.cooldown, dt)
	f.melee_cooldown = _combat_timer(f.melee_cooldown, dt)
	f.combo_left = move_toward(f.combo_left, 0.0, dt)
	f.slide = move_toward(f.slide, 0.0, dt)
	f.stagger = _combat_timer(f.stagger, dt)
	f.knocked = _combat_timer(f.knocked, dt)
	var strike_before := f.strike
	f.strike = move_toward(f.strike, 0.0, dt)
	f.flash = move_toward(f.flash, 0.0, dt)
	f.dodge = move_toward(f.dodge, 0.0, dt)
	f.pickup = move_toward(f.pickup, 0.0, dt)
	f.landing = move_toward(f.landing, 0.0, dt)
	f.recoil = move_toward(f.recoil, 0.0, dt)
	if f.exhausted > 0.0:
		f.exhausted = _combat_timer(f.exhausted, dt)
		if f.exhausted == 0.0:
			_recover_stamina(f)
	f.blocking = f.grounded and f.slide == 0.0 and not f.locked() and intent.get("block", false)
	var move: int = intent.get("move", 0)
	var vertical: int = intent.get("vertical", 0)
	var was_aiming := f.aiming
	f.aiming = f.item != null and intent.get("aim", false) and f.slide == 0.0 and not f.blocking and not f.locked() and f.strike == 0.0
	if f.aiming:
		if not was_aiming:
			f.elevation = 0.0
		if move != 0:
			f.facing = move
		f.elevation = clampf(f.elevation + vertical * dt * 1.85, -MAX_ELEVATION, MAX_ELEVATION)
	if f.aiming or f.blocking or f.locked() or f.climbing or move != f.sprint:
		f.sprint = 0
	if not f.aiming and not f.blocking and not f.locked() and f.slide == 0.0:
		if move != 0:
			f.facing = move
		if intent.get("slide", false) and f.sprint != 0 and f.grounded:
			f.slide_side = f.facing
			f.slide = SLIDE_TIME
			f.sprint = 0
			_burst(f.position, Color("ad8c80"), 8)
			_play("slide")
	f.crouched = f.grounded and vertical > 0 and not f.aiming and not f.locked() and f.slide == 0.0
	_step_stamina(f, dt)
	if not f.locked() and not f.blocking:
		if strike_before > MELEE_CONTACT + TIMER_EPSILON and f.strike <= MELEE_CONTACT + TIMER_EPSILON:
			_resolve_melee(f, target)
		if f.reload > 0.0:
			f.reload = _combat_timer(f.reload, dt)
			if f.reload == 0.0:
				_finish_reload(f)
		_use_item(f, intent)
	elif f.blocking:
		f.strike = 0.0
	_move_fighter(f, intent, move, vertical, dt)
	f.visual_crouch = move_toward(f.visual_crouch, float(f.crouched), dt * 8.0)
	f.visual_guard = move_toward(f.visual_guard, float(f.blocking), dt * 12.0)
	f.visual_air = move_toward(f.visual_air, float(not f.grounded and not f.climbing), dt * 10.0)

func _combat_timer(remaining: float, dt: float) -> float:
	return 0.0 if remaining <= dt + TIMER_EPSILON else remaining - dt

func _step_stamina(f: Fighter, dt: float) -> void:
	if f.exhausted > 0.0:
		return
	f.recovery_delay = move_toward(f.recovery_delay, 0.0, dt)
	var drain := HEAVY_DRAIN if f.is_heavy() else 0.0
	if f.sprint != 0 and f.grounded and not f.crouched and absf(f.move_speed) > 1.0:
		drain += SPRINT_COST / (HEAVY_FACTOR if f.is_heavy() else 1.0)
	if drain > 0.0:
		_spend_stamina(f, drain * dt)
	elif f.recovery_delay == 0.0 and not f.locked() and not f.blocking:
		f.stamina = move_toward(f.stamina, MAX_STAMINA, STAMINA_RECOVERY * dt)

func _spend_stamina(f: Fighter, amount: float) -> void:
	f.stamina = maxf(0.0, f.stamina - amount)
	f.recovery_delay = 0.55
	if f.stamina == 0.0 and f.exhausted == 0.0:
		f.exhausted = EXHAUST_TIME
		f.exhaust_taps = 0
		f.aiming = false
		f.blocking = false
		f.crouched = false
		f.climbing = false
		f.sprint = 0
		f.slide = 0.0
		f.strike = 0.0
		f.reload = 0.0
		f.pickup = 0.0
		f.move_speed = 0.0
		if f.team == 0:
			last_tap.clear()
		_burst(f.position - Vector2(0, 20), AMBER, 7)

func _recover_stamina(f: Fighter) -> void:
	f.exhausted = 0.0
	f.stamina = 35.0
	f.recovery_delay = 0.55

func _use_item(f: Fighter, intent: Dictionary) -> void:
	if f.slide > 0.0:
		return
	if f.crouched and intent.get("grab", false) and _near_item(f) != null:
		_grab(f)
		f.pickup = 0.28
		return
	if intent.get("throw", false) and f.item != null:
		_drop_item(f, true)
	elif intent.get("reload", false):
		_start_reload(f)
	if f.pickup > 0.0:
		return
	if f.aiming and intent.get("fire", false) and f.cooldown == 0.0 and f.reload == 0.0:
		if f.has_gun() and f.item.ammo > 0:
			_fire(f)
		elif f.item != null and f.item.kind == "claymore" and f.grounded:
			_place_mine(f)
	elif not f.aiming and intent.get("melee", false) and f.melee_cooldown <= TIMER_EPSILON:
		f.reload = 0.0
		f.melee_cooldown = MELEE_INTERVAL
		f.strike = 0.32

func _move_fighter(f: Fighter, intent: Dictionary, move: int, vertical: int, dt: float) -> void:
	var ladder := _near_ladder(f.position)
	var locked := f.locked()
	var jump: bool = intent.get("jump", false) and not (f.aiming or f.blocking or locked) and f.slide == 0.0
	if f.climbing and (ladder == Vector3.ZERO or (move != 0 and not f.aiming) or jump or locked):
		f.climbing = false
		if jump:
			f.grounded = true
	if not (f.aiming or f.blocking or jump or locked) and f.slide == 0.0 and ladder != Vector3.ZERO and vertical != 0 and f.pickup == 0.0:
		if f.climbing or vertical < 0 and f.position.y > ladder.y or vertical > 0 and f.position.y < ladder.z:
			f.climbing = true
			f.crouched = false
			f.sprint = 0
	if f.climbing:
		f.position.x = ladder.x
		f.velocity = Vector2.ZERO
		f.move_speed = 0.0
		if not f.aiming:
			f.position.y = clampf(f.position.y + vertical * 74.0 * dt, ladder.y, ladder.z)
			if f.position.y == ladder.y and vertical < 0 or f.position.y == ladder.z and vertical > 0:
				f.climbing = false
				f.grounded = true
		return
	if jump and f.grounded:
		f.velocity.y = -287.0
		f.grounded = false
		_spend_stamina(f, JUMP_COST / (HEAVY_FACTOR if f.is_heavy() else 1.0))
		_play("jump")
		_burst(f.position, Color("b49483"), 5)
	var speed := 182.0 if f.sprint != 0 else 119.0
	if f.crouched:
		speed *= 0.45
	if f.strike > 0.0:
		speed *= 0.62
	if f.locked() or f.aiming or f.blocking or f.pickup > 0.0:
		f.move_speed = 0.0
	elif f.slide > 0.0:
		f.move_speed = f.slide_side * lerpf(74.0, 218.0, f.slide / SLIDE_TIME)
	else:
		f.move_speed = move_toward(f.move_speed, move * speed, dt * (1040.0 if move == 0 else 850.0))
	f.velocity.x = f.move_speed + f.push
	f.push = move_toward(f.push, 0.0, 590.0 * dt)
	var previous_x := f.position.x
	if level == 1:
		f.position.x = clampf(f.position.x + f.velocity.x * dt, 9.0, WIDTH - 9.0)
	else:
		f.position.x += f.velocity.x * dt
	f.stride_distance = fposmod(f.stride_distance + absf(f.position.x - previous_x), 1440.0)
	var old_y := f.position.y
	var was_grounded := f.grounded
	f.velocity.y += 615.0 * dt
	f.position.y += f.velocity.y * dt
	f.grounded = false
	if f.velocity.y >= 0.0:
		var landing_y := _landing_y(f.position, old_y)
		if landing_y >= 0.0:
			if not was_grounded and f.velocity.y > 80.0:
				f.landing = 0.18
			f.position.y = landing_y
			f.velocity.y = 0.0
			f.grounded = true

func _near_ladder(position: Vector2) -> Vector3:
	if level == 1:
		return Vector3.ZERO
	for ladder in LADDERS:
		if absf(position.x - ladder.x) <= 7.0 and position.y >= ladder.y - 1.0 and position.y <= ladder.z:
			return ladder
	return Vector3.ZERO

func _landing_y(position: Vector2, old_y: float) -> float:
	if level == 1:
		return FLOOR if old_y <= FLOOR and position.y >= FLOOR else -1.0
	for platform in PLATFORMS:
		if position.x >= platform.x and position.x <= platform.y and old_y <= platform.z and position.y >= platform.z:
			return platform.z
	return -1.0

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
	if fighter.has_gun() and fighter.item.ammo < GEAR[fighter.item.kind].capacity and fighter.item.spare > 0 and fighter.reload == 0.0 and fighter.slide == 0.0:
		fighter.reload = GEAR[fighter.item.kind].reload
		_play("reload")

func _finish_reload(fighter: Fighter) -> void:
	if fighter.has_gun() and fighter.item.spare > 0:
		fighter.item.spare -= 1
		fighter.item.ammo = GEAR[fighter.item.kind].capacity
		_play("pick")

func _muzzle(fighter: Fighter) -> Vector2:
	return fighter.position + FighterArt.AIM_ORIGIN + fighter.direction() * FighterArt.muzzle_length(GEAR[fighter.item.kind])

func _fire(fighter: Fighter) -> void:
	var weapon: Dictionary = GEAR[fighter.item.kind]
	fighter.cooldown = weapon.cycle
	fighter.recoil = 0.16
	fighter.item.ammo -= 1
	var origin := _muzzle(fighter)
	var spread: float = weapon.spread
	var direction := fighter.direction().rotated(deg_to_rad(randf_range(-spread, spread)))
	bullets.append({
		"position": origin, "direction": direction, "left": weapon.range,
		"team": fighter.team, "damage": weapon.damage, "checked": false,
		"rocket": fighter.item.kind == "rpg",
	})
	_burst(origin, AMBER, 6)
	_play("shot")
	if fighter.item.ammo == 0:
		fighter.item = null
		fighter.reload = 0.0

func _resolve_melee(fighter: Fighter, target: Fighter) -> void:
	var distance := (target.position.x - fighter.position.x) * fighter.facing
	if distance < -4.0 or distance > 23.0 or absf(target.position.y - fighter.position.y) >= 14.0 or target.knocked > 0.0:
		fighter.combo_left = 0.0
		return
	if target.blocking and not target.locked():
		fighter.combo_left = 0.0
		_spend_stamina(target, GUARD_COST)
		_burst(target.position - Vector2(0, 22), MINT, 5)
		_play("block")
		return
	if not _hit(target, 14, fighter.facing, "melee"):
		fighter.combo_left = 0.0
		return
	fighter.combo_hits = fighter.combo_hits + 1 if fighter.combo_left > 0.0 else 1
	fighter.combo_left = COMBO_WINDOW
	if fighter.combo_hits == 3:
		fighter.combo_hits = 0
		fighter.combo_left = 0.0
		target.knocked = KNOCKDOWN_TIME
		target.knock_side = fighter.facing
		target.push = fighter.facing * 158.0
		target.stagger = 0.0
		target.combo_left = 0.0
	_play("punch")

func _hit(target: Fighter, damage: int, direction: int, kind: String) -> bool:
	if not target.active or target.hp == 0:
		return false
	if target.slide > 0 and (kind == "melee" or kind == "bullet" and randf() < BULLET_DODGE):
		target.dodge = 0.19
		_burst(target.position - Vector2(0, 9), MINT, 5)
		return false
	target.hp = maxi(0, target.hp - damage)
	target.flash = 0.14
	target.stagger = maxf(target.stagger, MELEE_STUN if kind == "melee" else 0.07)
	target.aiming = false
	target.blocking = false
	target.strike = 0.0
	if kind != "melee":
		target.push = direction * (48.0 if kind == "bullet" else 108.0)
	_burst(target.position - Vector2(0, 16), PAPER, 5)
	if target.hp == 0:
		target.knock_side = direction
	if target.hp == 0 and target.item != null:
		_drop_item(target, false)
	return true

func _hurtbox(fighter: Fighter) -> Rect2:
	if fighter.knocked > 0.14:
		return Rect2(fighter.position - Vector2(12, 8), Vector2(24, 8))
	var tall := 19.0 if fighter.crouched else 29.0
	return Rect2(fighter.position - Vector2(6, tall), Vector2(12, tall - 2))

func _step_bullets(dt: float) -> void:
	for index in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[index]
		var last: Vector2 = bullet.position
		var travel := minf((230.0 if bullet.rocket else 405.0) * dt, bullet.left)
		bullet.position += bullet.direction * travel
		bullet.left -= travel
		var target := fighters[1 - int(bullet.team)]
		var hit: bool = not bullet.checked and target.hp > 0 and _crosses(last, bullet.position, _hurtbox(target))
		var outside := not Rect2(0, 0, WIDTH, FLOOR).has_point(bullet.position)
		if bullet.rocket and (hit or bullet.left <= 0.0 or outside):
			_blast(bullet.position, bullet.team, bullet.damage, 31.0)
			bullets.remove_at(index)
		elif hit:
			bullet.checked = true
			if _hit(target, bullet.damage, 1 if bullet.direction.x > 0 else -1, "bullet"):
				bullets.remove_at(index)
		elif bullet.left <= 0.0 or outside:
			bullets.remove_at(index)

func _place_mine(fighter: Fighter) -> void:
	var location := fighter.position
	mines.append({"position": location, "team": fighter.team, "arming": 0.75})
	fighter.item = null
	_play("pick")

func _step_mines(dt: float) -> void:
	for index in range(mines.size() - 1, -1, -1):
		var mine := mines[index]
		mine.arming = maxf(0.0, mine.arming - dt)
		var target := fighters[1 - int(mine.team)]
		if mine.arming == 0.0 and target.position.distance_to(mine.position) <= 24.0:
			_blast(mine.position, mine.team, GEAR.claymore.damage, 29.0)
			mines.remove_at(index)

func _blast(position: Vector2, team: int, damage: int, radius: float) -> void:
	var target := fighters[1 - team]
	var impact := _hurtbox(target).get_center()
	var offset := impact - position
	if offset.length() <= radius:
		_hit(target, damage, 1 if offset.x >= 0.0 else -1, "blast")
	_burst(position, AMBER, 20)
	_burst(position, CORAL, 12)
	_play("shot")

func _crosses(start: Vector2, end: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(start) or bounds.has_point(end):
		return true
	var corner := bounds.position
	var across := Vector2(bounds.end.x, corner.y)
	var down := Vector2(corner.x, bounds.end.y)
	return Geometry2D.segment_intersects_segment(start, end, corner, across) != null or Geometry2D.segment_intersects_segment(start, end, across, bounds.end) != null or Geometry2D.segment_intersects_segment(start, end, bounds.end, down) != null or Geometry2D.segment_intersects_segment(start, end, down, corner) != null

func _step_items(dt: float) -> void:
	for index in range(items.size() - 1, -1, -1):
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
		if level == 1 and (item.position.x < 5.0 or item.position.x > WIDTH - 5.0):
			item.position.x = clampf(item.position.x, 5.0, WIDTH - 5.0)
			item.velocity.x *= -0.25
		if item.position.y > FALL_LIMIT:
			items.remove_at(index)
			continue
		if item.velocity.y < 0:
			continue
		var landing := _landing_y(item.position, last.y)
		if landing >= 0:
			item.position.y = landing
			item.rest = true
			item.thrown_by = -1
	for point in spawn_points:
		if point.item != null and items.has(point.item) and point.item.position.distance_to(point.location) < 12.0:
			continue
		point.wait = maxf(0.0, point.wait - dt)
		if point.wait == 0.0:
			point.item = _new_item(point.pool[point.next], point.location)
			point.next = (point.next + 1) % point.pool.size()
			point.wait = RESPAWN_TIME

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
	if level == 1:
		_draw_testing()
	else:
		_draw_rooftop()
		_draw_platforms()
		_draw_ladders()
	for item in items:
		_draw_item(item)
	for point in spawn_points:
		if point.item == null or not items.has(point.item):
			var spot: Vector2 = point.location
			draw_rect(Rect2(spot - Vector2(6, 2), Vector2(12, 2)), Color("59424e"))
	for mine in mines:
		var spot: Vector2 = mine.position.round()
		draw_rect(Rect2(spot - Vector2(5, 4), Vector2(10, 4)), Color("15181a"))
		draw_rect(Rect2(spot - Vector2(2, 3), Vector2(2, 1)), AMBER if mine.arming > 0.0 else CORAL.darkened(0.32))
	for bullet in bullets:
		var p: Vector2 = bullet.position
		draw_line(p.round(), (p - bullet.direction * (11.0 if bullet.rocket else 5.0)).round(), CORAL if bullet.rocket else AMBER, 3.0 if bullet.rocket else 2.0)
		draw_rect(Rect2(p.round(), Vector2(2, 1)), PAPER)
	for fighter in fighters:
		if fighter.active:
			_draw_fighter(fighter)
	for spark in sparks:
		draw_rect(Rect2(spark.position.round(), Vector2(2, 1)), spark.color)
	if state == "playing" and not fighters.is_empty():
		var near := _near_item(fighters[0])
		if near != null:
			var y := near.position.y - 22.0
			var label: String = GEAR[near.kind].label
			var label_width := maxf(38.0, ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0)
			draw_rect(Rect2(near.position.x - label_width / 2.0, y - 18, label_width, 21), INK)
			_text(label, Vector2(near.position.x, y - 9), 8, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			_text("↓ + N", Vector2(near.position.x, y), 9, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
func _draw_overlay() -> void:
	if state != "level_select":
		_draw_hud()
	if state != "playing":
		_draw_panel()
	if state != "level_select":
		_draw_controls()

func _draw_rooftop() -> void:
	var roof := Color("020205")
	draw_colored_polygon(PackedVector2Array([
		Vector2(ROOF_LEFT + 13.0, 220), Vector2(ROOF_RIGHT - 13.0, 220),
		Vector2(ROOF_RIGHT, FLOOR), Vector2(ROOF_RIGHT, 262),
		Vector2(ROOF_LEFT, 262), Vector2(ROOF_LEFT, FLOOR),
	]), roof)
	draw_rect(Rect2(ROOF_LEFT + 5, 263, ROOF_RIGHT - ROOF_LEFT - 10, 190), Color("050509"))
	draw_line(Vector2(ROOF_LEFT + 13.0, 220), Vector2(ROOF_RIGHT - 13.0, 220), Color("5a3946"))
	draw_line(Vector2(ROOF_LEFT, FLOOR), Vector2(ROOF_LEFT, 262), Color("573846"))
	draw_line(Vector2(ROOF_RIGHT, FLOOR), Vector2(ROOF_RIGHT, 262), Color("573846"))
	draw_line(Vector2(ROOF_LEFT, 262), Vector2(ROOF_RIGHT, 262), Color("3b2832"))
	var ring := PackedVector2Array()
	for segment in range(41):
		var angle := float(segment) / 40.0 * TAU
		ring.append(Vector2(WIDTH / 2.0 + cos(angle) * 95.0, 243.0 + sin(angle) * 12.0))
	draw_polyline(ring, Color("593d43"))
	var marking := Color("694850")
	draw_rect(Rect2(227, 235, 5, 15), marking)
	draw_rect(Rect2(248, 235, 5, 15), marking)
	draw_rect(Rect2(232, 241, 16, 4), marking)
	for x in [ROOF_LEFT + 2.0, ROOF_RIGHT - 6.0]:
		draw_rect(Rect2(x, FLOOR - 2, 4, 1), Color("c87963"))

func _draw_testing() -> void:
	draw_rect(Rect2(-280, FLOOR - 7, 1040, 130), Color("f1f4f4"))
	draw_line(Vector2(-280, FLOOR - 7), Vector2(760, FLOOR - 7), Color("aab6be"))
	for wall_x in [4.0, WIDTH - 7.0]:
		draw_rect(Rect2(wall_x, FLOOR - 44, 3, 38), Color("bdc9cc"))
	for plate in lab_plates:
		var x: float = plate.x
		var can_spawn_rival: bool = plate.kind == "vanta" and not fighters[1].active
		var indicator := Color("5a999c") if can_spawn_rival or plate.kind != "vanta" else Color("aeb8bf")
		draw_rect(Rect2(x - LAB_PLATE_WIDTH / 2.0, FLOOR - 1, LAB_PLATE_WIDTH, 5), Color("424d58"))
		draw_rect(Rect2(x - LAB_PLATE_WIDTH / 2.0 + 1, FLOOR - (1 if plate.down else 3), LAB_PLATE_WIDTH - 2, 3), indicator)
		var label: String = "VANTA IA" if plate.kind == "vanta" else GEAR[plate.kind].label
		_text(label, Vector2(x, FLOOR + 14), 8, Color("394955"), HORIZONTAL_ALIGNMENT_CENTER)

func _draw_platforms() -> void:
	for platform in PLATFORMS:
		if platform.z == FLOOR:
			continue
		var span: float = platform.y - platform.x
		draw_rect(Rect2(platform.x, platform.z, span, 7), Color("030307"))
		draw_rect(Rect2(platform.x, platform.z, span, 1), Color("603d49"))
		draw_rect(Rect2(platform.x + 3, platform.z + 3, span - 6, 1), Color("110d15"))
		for x: float in [platform.x + 9, platform.y - 12]:
			draw_rect(Rect2(x, platform.z + 7, 3, 18), Color("09080e"))

func _draw_ladders() -> void:
	for ladder in LADDERS:
		var top: float = ladder.y + 3.0
		var bottom: float = ladder.z
		for side in [-5, 4]:
			draw_rect(Rect2(ladder.x + side, top, 2, bottom - top), Color("08070d"))
			draw_rect(Rect2(ladder.x + side, top, 1, bottom - top), Color("50323e"))
		for y in range(int(top) + 4, int(bottom), 6):
			draw_rect(Rect2(ladder.x - 4.0, y, 9, 2), Color("53343e"))

func _draw_item(item: Item) -> void:
	var position := item.position.round()
	if item.rest:
		draw_rect(Rect2(position.x - 7, position.y - 1, 14, 1), INK)
		position.y -= 7.0 + roundf(sin(elapsed * 4.0 + position.x) * 2.0)
	var gear: Dictionary = GEAR[item.kind]
	var long: float = gear.size
	var angle := 0.0 if item.rest else snappedf(item.velocity.angle(), PI / 12)
	draw_set_transform(position, angle)
	draw_rect(Rect2(-long / 2.0 - 1, -2, long + 2, 5), Color("211d28"))
	draw_rect(Rect2(-long / 2.0, -1, long, 2), Color(gear.color))
	if item.is_gun():
		draw_rect(Rect2(-long / 2.0 + 1, 1, 3, 3), Color("806369"))
	else:
		draw_rect(Rect2(-long / 2.0 + 2, 1, 1, 2), MINT.darkened(0.4))
		draw_rect(Rect2(long / 2.0 - 3, 1, 1, 2), MINT.darkened(0.4))
	draw_set_transform(Vector2.ZERO)

func _draw_fighter(f: Fighter) -> void:
	var gear := {}
	if f.item != null and not (f.locked() or f.blocking or f.climbing or f.strike > 0.0 or f.pickup > 0.0):
		gear = GEAR[f.item.kind]
	FighterArt.paint(self, f, gear)
	var position := f.position.round()
	if f.aiming and f.has_gun():
		_draw_aim(f)
	if f.exhausted > 0.0:
		var message := "AGOTADO · FLECHAS" if f.team == 0 and f.exhaust_taps < RECOVERY_TAPS else "AGOTADO"
		_text(message, position - Vector2(0, 35), 8, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	elif f.dodge > 0.0:
		_text("ESQUIVA", position - Vector2(0, 22), 8, MINT, HORIZONTAL_ALIGNMENT_CENTER)
	if f.reload > 0.0 and not f.locked():
		var progress := 1.0 - f.reload / float(GEAR[f.item.kind].reload)
		draw_rect(Rect2(position.x - 10, position.y - 41, 20, 3), INK)
		draw_rect(Rect2(position.x - 9, position.y - 40, roundf(progress * 18.0), 1), AMBER)

func _draw_aim(f: Fighter) -> void:
	var dir := f.direction()
	var origin := (f.position + FighterArt.AIM_ORIGIN).round()
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
	if level == 1:
		hud.draw_rect(Rect2(0, 0, WIDTH, 53), Color("1e2530"))
	for f in fighters:
		var left := f.team == 0
		var x := 17.0 if left else 284.0
		var color := MINT if left else CORAL
		var aligned := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		var edge := x if left else x + 179.0
		_hud_text("TÚ" if left else ("VANTA IA" if f.ai else "VANTA"), Vector2(edge, 20), 11, color, aligned)
		var score := "" if level == 1 else "◆".repeat(wins[f.team]) + "◇".repeat(2 - wins[f.team])
		_hud_text(score, Vector2(x + 179.0 if left else x, 20), 11, color, HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT)
		hud.draw_rect(Rect2(x, 25, 179, 6), INK)
		hud.draw_rect(Rect2(x, 25, 179, 6), color, false)
		var live := roundf(175.0 * f.hp / MAX_HEALTH)
		hud.draw_rect(Rect2(x + 2.0 if left else x + 177.0 - live, 27, live, 2), color)
		var stamina_width := roundf(175.0 * f.stamina / MAX_STAMINA)
		var stamina_color := AMBER if f.stamina > 25.0 else CORAL
		hud.draw_rect(Rect2(x, 33, 179, 4), Color("352835"))
		hud.draw_rect(Rect2(x + 2.0 if left else x + 177.0 - stamina_width, 34, stamina_width, 2), stamina_color)
		var label := "PUÑOS" if f.active else "AUSENTE"
		if f.item != null:
			label = GEAR[f.item.kind].label
			if f.is_heavy():
				label += " · PESADA"
			if f.has_gun():
				label += "  %d/%d  ·  %d RESERVA" % [f.item.ammo, GEAR[f.item.kind].capacity, f.item.spare]
			if f.reload > 0:
				label = "RECARGANDO…"
		_hud_text(label, Vector2(edge, 47), 9, PAPER, aligned)
	_hud_text("PRUEBAS" if level == 1 else "RONDA %d" % round_number, Vector2(240, 26), 10, PAPER, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_panel() -> void:
	hud.draw_rect(Rect2(0, 0, WIDTH, 270), Color(0.02, 0.02, 0.04, 0.42))
	hud.draw_rect(Rect2(122, 74, 236, 135), Color("5d4552"))
	hud.draw_rect(Rect2(123, 75, 234, 133), Color("11121a"))
	hud.draw_rect(Rect2(123, 75, 234, 2), AMBER)
	if state == "level_select" or state == "paused":
		var title := "ELIGE UN NIVEL" if state == "level_select" else "EN PAUSA"
		_hud_text(title, Vector2(240, 103), 18, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var options := _menu_options()
		for index in options.size():
			var row := _menu_row(index)
			var selected := index == menu_index
			hud.draw_rect(row, AMBER if selected else Color("222331"))
			_hud_text(options[index], Vector2(240, row.position.y + 13), 11, INK if selected else PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_hud_text(banner, Vector2(240, 103), 10, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
		_hud_text(panel_title, Vector2(240, 140), 22, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		_hud_text(panel_copy, Vector2(240, 167), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_controls() -> void:
	hud.draw_rect(Rect2(0, 270, WIDTH, 38), Color("191f28"))
	hud.draw_rect(Rect2(0, 270, WIDTH, 1), Color("56464b"))
	_hud_text("←/→ mover  ·  ↑ saltar  ·  Doble ←/→ correr  ·  ↓ al correr desliza", Vector2(240, 281), 9, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_text("N golpe  ·  ↓ + N recoger  ·  J recarga  ·  ↓ + J bloqueo  ·  Q lanzar", Vector2(240, 292), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_text("M apunta  ·  M + , dispara o coloca mina  ·  N cancela  ·  ESC pausa", Vector2(240, 303), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _hud_text(value: String, position: Vector2, size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_text(value, position, size, color, alignment, hud)

func _text(value: String, position: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, canvas: Node2D = null) -> void:
	var font := ThemeDB.fallback_font
	var length := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := position.x
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x -= length / 2.0
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= length
	var target := self if canvas == null else canvas
	target.draw_string(font, Vector2(roundf(x), position.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _build_sounds() -> void:
	for i in 5:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	var effects := {
		"pick": Vector3(330, 700, 0.11), "jump": Vector3(185, 340, 0.10), "slide": Vector3(103, 47, 0.15),
		"throw": Vector3(235, 100, 0.12), "shot": Vector3(120, 35, 0.14), "punch": Vector3(135, 56, 0.10),
		"block": Vector3(260, 125, 0.12), "win": Vector3(300, 610, 0.24), "reload": Vector3(145, 191, 0.12)
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
