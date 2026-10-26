class_name CameraBG3
extends Node3D
## BG3-style tactical camera: fixed ~50° pitch, mouse-wheel / pinch zoom by distance, no rotation.
## Framing: the heroes' on-screen extent (front-most head → back-most ring) is kept centred in the
## HUD's free band (between the top panel and the FOCAR button). When the party spreads wider than
## that band, the camera pulls back just enough (temporary, on top of the player's zoom) and eases
## back to the chosen distance when the party regroups.

const PITCH_DEG := 50.0
const DIST_MIN := 9.0
const DIST_MAX := 30.0
const DIST_DEFAULT := 17.0
const ZOOM_STEP := 1.12
const FOLLOW_RATE := 4.0
const FIT_RATE := 2.5
const FIT_FILL := 0.9  # use at most this share of the free band before pulling back
const FIT_RELAX := 0.7  # below this share, ease the extra distance back to zero

var battle: Battle3D
var cam: Camera3D
var distance := DIST_DEFAULT  # the player's zoom
var extra := 0.0  # temporary pull-back to fit a spread party
var focus := Vector3.ZERO
var _shake := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	focus = battle.hero_centroid()
	_place()


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, DIST_MIN, DIST_MAX)


func effective_distance() -> float:
	return clampf(distance + extra, DIST_MIN, DIST_MAX)


## Screen band free of HUD (top panel bottom → FOCAR area top), with a small margin.
func free_band() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	if battle.hud == null or battle.hud.top_panel == null:
		return Vector2(0.0, vp.y)
	return Vector2(battle.hud.top_panel.get_global_rect().end.y + 12.0, battle.hud.focus_area().position.y - 12.0)


func _process(delta: float) -> void:
	var heroes := battle.alive(Unit3D.TEAM_HEROES)
	if heroes.is_empty():
		heroes = battle.units.filter(func(u: Unit3D) -> bool: return u.is_hero())
	# Horizontal: centre of the party's x extent. Depth: steer so the on-screen extent sits in the
	# middle of the free band.
	var min_x := INF
	var max_x := -INF
	var top_y := INF
	var bottom_y := -INF
	for h in heroes:
		min_x = minf(min_x, h.global_position.x)
		max_x = maxf(max_x, h.global_position.x)
		if not cam.is_position_behind(h.head()):
			top_y = minf(top_y, cam.unproject_position(h.head()).y)
		var ring_front := h.global_position + Vector3(0, 0, h.radius + 0.45)
		if not cam.is_position_behind(ring_front):
			bottom_y = maxf(bottom_y, cam.unproject_position(ring_front).y)
	var band := free_band()
	var band_h := maxf(band.y - band.x, 1.0)
	var want := focus
	want.x = (min_x + max_x) * 0.5
	if top_y < INF and bottom_y > -INF:
		var err_px := (top_y + bottom_y) * 0.5 - (band.x + band.y) * 0.5
		var metres_per_px := 2.0 * effective_distance() * tan(deg_to_rad(cam.fov) * 0.5) / get_viewport().get_visible_rect().size.y
		want.z = focus.z + err_px * metres_per_px / sin(deg_to_rad(PITCH_DEG))
		var span := (bottom_y - top_y) / band_h
		if span > FIT_FILL:
			extra = move_toward(extra, DIST_MAX - distance, delta * FIT_RATE * (span - FIT_FILL) * 20.0)
		elif span < FIT_RELAX:
			extra = move_toward(extra, 0.0, delta * FIT_RATE)
	var r := Battle3D.ARENA.grow(-3.0)
	want = Vector3(clampf(want.x, r.position.x, r.end.x), 0.0, clampf(want.z, r.position.y, r.end.y))
	focus = focus.lerp(want, 1.0 - exp(-FOLLOW_RATE * delta))
	_place()
	if _shake > 0.0:
		cam.h_offset = randf_range(-1, 1) * _shake
		cam.v_offset = randf_range(-1, 1) * _shake
		_shake = move_toward(_shake, 0.0, delta * 1.5)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _place() -> void:
	var p := deg_to_rad(PITCH_DEG)
	var d := effective_distance()
	cam.global_position = focus + Vector3(0.0, sin(p) * d, cos(p) * d)
	cam.look_at(focus, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.0 / ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(ZOOM_STEP)
	elif event is InputEventMagnifyGesture:
		zoom_by(1.0 / (event as InputEventMagnifyGesture).factor)
