class_name BattleCamera
extends Camera2D
## BG3-style 2D camera: follows the heroes' centroid, mouse-wheel / pinch-gesture zoom, locked
## to the arena bounds (zoom-out is capped so the view never exceeds the arena). No rotation.

const ZOOM_DEFAULT := 0.9
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.12

var battle: Battle
var _shake := 0.0


func _ready() -> void:
	var r := Battle.ARENA
	limit_left = int(r.position.x)
	limit_top = int(r.position.y)
	limit_right = int(r.end.x)
	limit_bottom = int(r.end.y)
	limit_smoothed = true
	position_smoothing_enabled = true
	position_smoothing_speed = 4.0
	_set_zoom(ZOOM_DEFAULT)
	get_viewport().size_changed.connect(func() -> void: _set_zoom(zoom.x))


func min_zoom() -> float:
	var vp := get_viewport_rect().size
	return maxf(vp.x / Battle.ARENA.size.x, vp.y / Battle.ARENA.size.y)


func snap() -> void:
	global_position = battle.hero_centroid()
	reset_smoothing()


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func zoom_by(factor: float) -> void:
	_set_zoom(zoom.x * factor)


func _set_zoom(z: float) -> void:
	z = clampf(z, min_zoom(), ZOOM_MAX)
	zoom = Vector2(z, z)


func _process(delta: float) -> void:
	global_position = battle.hero_centroid()
	if _shake > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, delta * 45.0)
	else:
		offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / ZOOM_STEP)
	elif event is InputEventMagnifyGesture:
		zoom_by((event as InputEventMagnifyGesture).factor)
