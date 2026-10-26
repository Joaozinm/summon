class_name CameraBG3
extends Node3D
## BG3-style tactical camera: fixed ~50° pitch looking down at the heroes' centroid, smooth follow,
## mouse-wheel / pinch zoom by distance, focus point clamped inside the arena. No rotation (yet).

const PITCH_DEG := 50.0
const DIST_MIN := 9.0
const DIST_MAX := 30.0
const DIST_DEFAULT := 17.0
const ZOOM_STEP := 1.12
const FOLLOW_RATE := 4.0
## Aim this far ahead of the heroes (toward the enemy side, -Z) so the fight in front fits the
## portrait screen. The camera still follows the heroes' centroid.
const LOOK_AHEAD := 2.5

var battle: Battle3D
var cam: Camera3D
var distance := DIST_DEFAULT
var focus := Vector3.ZERO
var _shake := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	focus = _wanted()
	_place()


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, DIST_MIN, DIST_MAX)


func _wanted() -> Vector3:
	var c := battle.hero_centroid() + Vector3(0, 0, -LOOK_AHEAD)
	var r := Battle3D.ARENA.grow(-3.0)
	return Vector3(clampf(c.x, r.position.x, r.end.x), 0.0, clampf(c.z, r.position.y, r.end.y))


func _process(delta: float) -> void:
	focus = focus.lerp(_wanted(), 1.0 - exp(-FOLLOW_RATE * delta))
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
	cam.global_position = focus + Vector3(0.0, sin(p) * distance, cos(p) * distance)
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
