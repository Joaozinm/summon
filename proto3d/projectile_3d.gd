class_name Projectile3D
extends Node3D
## Arrow / arcane bolt / sling stone (v1 rules: gentle homing, hits the first enemy it touches).
## PLACEHOLDER visual: a small unshaded sphere at chest height.

const SPEED := 560.0 / 40.0
const TURN_RATE := 3.5
const HIT_RADIUS := 5.0 / 40.0
const FLY_HEIGHT := 1.0

var source: Unit3D
var target: Unit3D
var amount: float
var team: int
var battle: Battle3D
var done := false
var _dir := Vector3.FORWARD
var _travelled := 0.0
var _max_travel := 10.0
var _color := Color.WHITE


func setup(src: Unit3D, tgt: Unit3D, dmg: float, owner_battle: Battle3D) -> void:
	source = src
	target = tgt
	amount = dmg
	team = src.team
	battle = owner_battle
	_color = Color(src.def.accent) if src.id == "orin" else Color(src.def.color).lightened(0.35)
	position = src.flat_pos() + Vector3(0, FLY_HEIGHT, 0)
	_dir = (tgt.flat_pos() - src.flat_pos()).normalized()
	_max_travel = src.attack_range * 1.4


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = _color
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func tick(delta: float) -> void:
	if done:
		return
	if is_instance_valid(target) and not target.dead:
		var want := target.flat_pos() - Vector3(position.x, 0.0, position.z)
		var ang := Vector2(_dir.x, _dir.z).angle_to(Vector2(want.x, want.z))
		var turn := clampf(ang, -TURN_RATE * delta, TURN_RATE * delta)
		var d2 := Vector2(_dir.x, _dir.z).rotated(turn)
		_dir = Vector3(d2.x, 0.0, d2.y)
	var step := SPEED * delta
	position += _dir * step
	_travelled += step
	var flat := Vector3(position.x, 0.0, position.z)
	for u in battle.alive(1 - team):
		if flat.distance_to(u.flat_pos()) <= u.radius + HIT_RADIUS:
			battle.projectile_hit(self, u)
			_finish()
			return
	if _travelled > _max_travel or not Battle3D.ARENA.has_point(Vector2(position.x, position.z)):
		_finish()


func _finish() -> void:
	done = true
	queue_free()
