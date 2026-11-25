extends Node2D

const SKY = preload("res://assets/cielo_atardecer.png")
const FAR_CITY = preload("res://assets/ciudad_lejana.png")
const NEAR_CITY = preload("res://assets/ciudad_cercana.png")
const UFO_INTERVAL := 30.0
const UFO_CHANCE := 0.05
var time := 0.0
var ufo_timer := 0.0
var ufo_started := -20.0
var testing := false
var travel := Vector2.ZERO

func reset(is_testing: bool) -> void:
	testing = is_testing
	time = 0.0
	ufo_timer = 0.0
	ufo_started = -20.0
	queue_redraw()

func advance(dt: float) -> void:
	if testing:
		return
	time += dt
	ufo_timer += dt
	while ufo_timer >= UFO_INTERVAL:
		ufo_timer -= UFO_INTERVAL
		_try_ufo(randf())
	queue_redraw()

func follow(center: Vector2) -> void:
	travel = center - Vector2(240, 158)
	queue_redraw()

func _try_ufo(roll: float) -> void:
	if roll < UFO_CHANCE:
		ufo_started = time

func _draw() -> void:
	if testing:
		_draw_lab()
		return
	draw_rect(Rect2(0, 0, 480, 308), Color("35282f"))
	draw_texture(SKY, Vector2.ZERO)
	_cloud(436 - fposmod(time * 5.0, 590.0), 78, 0.35)
	_cloud(311 - fposmod(time * 8.0, 600.0), 102, 0.50)
	_cloud(515 - fposmod(time * 6.5 + 300.0, 645.0), 139, 0.42)
	var bird_x := -28.0 - travel.x * 0.15 + fposmod(time * 28.0 + 52.0, 580.0)
	for index in 4:
		var bird := Vector2(bird_x - index * 11, 118 - index * 3 - travel.y * 0.09 + sin(time * 2.3 + index) * 2.0).round()
		var wing := roundf(sin(time * 12.0 + index * 0.8) * 3.0)
		draw_line(bird + Vector2(-4, wing), bird, Color("493440"), 1.0)
		draw_line(bird, bird + Vector2(4, wing - 1), Color("493440"), 1.0)
	var plane := Vector2(520 - fposmod(time * 19.0 + 410.0, 640.0), 63) - travel * 0.10
	draw_line(plane + Vector2(10, 2), plane + Vector2(42, 3), Color(0.91, 0.62, 0.59, 0.32))
	draw_rect(Rect2(plane, Vector2(15, 2)), Color("503646"))
	draw_line(plane + Vector2(6, 2), plane + Vector2(11, 6), Color("503646"), 2)
	draw_line(plane + Vector2(12, 0), plane + Vector2(15, -3), Color("503646"), 1)
	if fposmod(time, 1.2) < 0.15:
		draw_rect(Rect2(plane + Vector2(10, 4), Vector2(1, 1)), Color("fbd7ac"))
	var ufo_age := time - ufo_started
	if ufo_age < 8.0:
		var ufo := Vector2(-28.0 + ufo_age * 67.0, 83 + sin(ufo_age * 2.1) * 7.0).round()
		draw_rect(Rect2(ufo - Vector2(5, 4), Vector2(10, 4)), Color("29243a"))
		draw_rect(Rect2(ufo - Vector2(13, 1), Vector2(26, 3)), Color("29243a"))
		draw_rect(Rect2(ufo - Vector2(9, -2), Vector2(18, 2)), Color("493857"))
		for index in 5:
			var light := Color("a3fee3") if int(ufo_age * 12.0) % 5 == index else Color("659c9c")
			draw_rect(Rect2(ufo + Vector2(index * 4 - 8, 2), Vector2(2, 1)), light)

	_draw_city(FAR_CITY, 0.17)
	_draw_city(NEAR_CITY, 0.34)

func _draw_city(city: Texture2D, depth: float) -> void:
	var offset := roundf(fposmod(-travel.x * depth, 480.0)) - 480.0
	var height := roundf(clampf(-travel.y * depth, -26.0, 18.0))
	draw_texture(city, Vector2(offset, height))
	draw_texture(city, Vector2(offset + 480.0, height))

func _cloud(x: float, y: float, opacity: float) -> void:
	var offset := (Vector2(x, y) - travel * (opacity * 0.32)).round()
	var color := Color(0.93, 0.53, 0.50, opacity)
	draw_rect(Rect2(offset, Vector2(96, 3)), color)
	draw_rect(Rect2(offset + Vector2(16, -3), Vector2(54, 3)), color)
	draw_rect(Rect2(offset + Vector2(24, 3), Vector2(83, 2)), color.lightened(0.18))

func _draw_lab() -> void:
	draw_rect(Rect2(0, 0, 480, 308), Color("f5f5f4"))
	draw_rect(Rect2(0, 56, 480, 143), Color("dfe5e8"))
	draw_rect(Rect2(0, 65, 480, 125), Color("b9c8cf"))
	draw_rect(Rect2(0, 68, 480, 120), Color("ecf4f6"))
	for x in range(-32, 500, 96):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 49, 68), Vector2(x + 81, 68), Vector2(x + 26, 188), Vector2(x - 6, 188),
		]), Color("f8fcfc"))
	for x in [12, 124, 239, 354, 466]:
		draw_rect(Rect2(x, 65, 2, 125), Color("c5d2d8"))
	for y in [56, 64, 188, 197, 212]:
		draw_rect(Rect2(0, y, 480, 1), Color("c8d1d4"))
