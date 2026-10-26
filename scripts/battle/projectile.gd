class_name Projectile
extends Node2D
## Arrow / arcane bolt / sling stone. Flies with gentle homing and hits the first enemy it
## touches — so a guard standing in the line of fire actually blocks shots.

const SPEED := 560.0
const TURN_RATE := 3.5
const HIT_RADIUS := 5.0

var source: Unit
var target: Unit
var amount: float
var team: int
var battle: Battle
var color: Color
var done := false
var _dir := Vector2.RIGHT
var _travelled := 0.0
var _max_travel := 400.0


func setup(src: Unit, tgt: Unit, dmg: float, owner_battle: Battle) -> void:
	source = src
	target = tgt
	amount = dmg
	team = src.team
	battle = owner_battle
	color = src.def.accent if src.id == "orin" else src.def.color.lightened(0.35)
	position = src.position
	_dir = (tgt.position - src.position).normalized()
	_max_travel = src.attack_range * 1.4
	rotation = _dir.angle()


func tick(delta: float) -> void:
	if done:
		return
	if is_instance_valid(target) and not target.dead:
		var ang := _dir.angle_to(target.position - position)
		_dir = _dir.rotated(clampf(ang, -TURN_RATE * delta, TURN_RATE * delta))
	var step := SPEED * delta
	position += _dir * step
	_travelled += step
	rotation = _dir.angle()
	for u in battle.alive(1 - team):
		if position.distance_to(u.position) <= u.radius + HIT_RADIUS:
			battle.projectile_hit(self, u)
			_finish()
			return
	if _travelled > _max_travel or not Battle.ARENA.has_point(position):
		_finish()


func _finish() -> void:
	done = true
	queue_free()


# Code-drawn (not part of the art delivery). Drawn LIFT px above its logical ground position so it
# flies at chest height next to the sprites; hit-testing still uses the ground position.
const LIFT := 34.0


func _draw() -> void:
	draw_set_transform(Vector2(0, -LIFT).rotated(-rotation))
	draw_line(Vector2(-14, 0), Vector2.ZERO, Color(color, 0.5), 3.0)
	draw_circle(Vector2.ZERO, 4.0, color)
