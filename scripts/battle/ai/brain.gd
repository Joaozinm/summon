class_name Brain
extends RefCounted
## Base AI. Each tick a brain sets `me.move_dir` (unit vector or zero) and may call
## me.try_attack / me.try_heal. Shared steering and targeting helpers live here.

const WALL_MARGIN := 140.0

var me: Unit
var battle: Battle


func setup(unit: Unit, owner_battle: Battle) -> void:
	me = unit
	battle = owner_battle


func think(_delta: float) -> void:
	pass


## Called by Battle when `me` lands a killing blow.
func on_kill(_victim: Unit) -> void:
	pass


# --- queries ---------------------------------------------------------------------------------

func enemies() -> Array[Unit]:
	return battle.alive(1 - me.team)


func allies() -> Array[Unit]:
	return battle.alive(me.team)


func dist(u: Unit) -> float:
	return me.position.distance_to(u.position)


func nearest(list: Array[Unit], from := Vector2.INF) -> Unit:
	var origin := me.position if from == Vector2.INF else from
	var best: Unit = null
	var best_d := INF
	for u in list:
		var d := origin.distance_to(u.position)
		if d < best_d:
			best_d = d
			best = u
	return best


## Unit minimizing `score` (ties keep the first).
func pick_min(list: Array[Unit], score: Callable) -> Unit:
	var best: Unit = null
	var best_s := INF
	for u in list:
		var s: float = score.call(u)
		if s < best_s:
			best_s = s
			best = u
	return best


# --- steering --------------------------------------------------------------------------------

func go_to(p: Vector2, stop := 4.0) -> void:
	if me.position.distance_to(p) > stop:
		me.move_dir = (p - me.position).normalized()


func hold() -> void:
	me.move_dir = Vector2.ZERO


## Direction away from `threat`, bent toward the arena centre near walls so kiting units
## slide along edges instead of pinning themselves in corners.
func flee_dir(threat: Vector2) -> Vector2:
	var away := (me.position - threat).normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN if me.is_hero() else Vector2.UP
	var r := Battle.ARENA
	var p := me.position
	var edge := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
	var w := clampf(1.0 - edge / WALL_MARGIN, 0.0, 1.0)
	var to_center := (r.get_center() - p).normalized()
	var d := away + to_center * w * 1.6
	if d.dot(threat - p) > 0.0:  # never run back through the threat
		var side := away.orthogonal()
		d = side if side.dot(to_center) >= 0.0 else -side
	return d.normalized()


func flee(threat: Vector2) -> void:
	me.move_dir = flee_dir(threat)


## Walk into reach of `target` (melee: contact; ranged: just inside range) and attack.
func engage(target: Unit) -> void:
	if target == null:
		hold()
		return
	if me.is_ranged():
		keep_range(target, me.attack_range * 0.8)
	elif not me.in_reach(target):
		go_to(target.position)
	else:
		hold()
	me.try_attack(target)


## Ranged spacing: approach when out of range, back off when closer than `ideal - band`.
func keep_range(target: Unit, ideal: float, band := 40.0) -> void:
	var d := dist(target)
	if d > minf(ideal + band, me.attack_range * 0.95):
		go_to(target.position)
	elif d < ideal - band:
		flee(target.position)
	else:
		hold()
