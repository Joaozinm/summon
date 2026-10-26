class_name Brains3D
## v1 AIs ported to the 3D prototype — same rules, distances in metres (v1 px / 40).
## Each tick a brain sets `me.move_dir` (XZ unit vector or zero) and may attack / heal.

const PX := 1.0 / 40.0


static func make(kind: String) -> AI:
	match kind:
		"muralha": return Muralha.new()
		"paciencia": return Paciencia.new()
		"triagem": return Triagem.new()
		"oportunista": return Oportunista.new()
		"rastejante": return Rastejante.new()
		"fundeiro": return Fundeiro.new()
		"bruto": return Bruto.new()
	push_error("unknown brain: %s" % kind)
	return AI.new()


class AI extends RefCounted:
	const WALL_MARGIN := 140.0 * PX

	var me: Unit3D
	var battle: Battle3D

	func setup(unit: Unit3D, owner_battle: Battle3D) -> void:
		me = unit
		battle = owner_battle

	func think(_delta: float) -> void:
		pass

	func on_kill(_victim: Unit3D) -> void:
		pass

	func enemies() -> Array[Unit3D]:
		return battle.alive(1 - me.team)

	func allies() -> Array[Unit3D]:
		return battle.alive(me.team)

	func dist(u: Unit3D) -> float:
		return me.dist_to(u)

	func nearest(list: Array[Unit3D], from := Vector3.INF) -> Unit3D:
		var origin := me.flat_pos() if from == Vector3.INF else from
		var best: Unit3D = null
		var best_d := INF
		for u in list:
			var d := origin.distance_to(u.flat_pos())
			if d < best_d:
				best_d = d
				best = u
		return best

	func pick_min(list: Array[Unit3D], score: Callable) -> Unit3D:
		var best: Unit3D = null
		var best_s := INF
		for u in list:
			var s: float = score.call(u)
			if s < best_s:
				best_s = s
				best = u
		return best

	func go_to(p: Vector3, stop := 0.1) -> void:
		if me.flat_pos().distance_to(Vector3(p.x, 0.0, p.z)) > stop:
			me.move_dir = me.nav_dir(p)

	func hold() -> void:
		me.move_dir = Vector3.ZERO

	## Away from `threat`, bent toward the arena centre near walls (v1 flee_dir on XZ).
	func flee_dir(threat: Vector3) -> Vector3:
		var p := me.flat_pos()
		var away := p - Vector3(threat.x, 0.0, threat.z)
		away = away.normalized() if away.length() > 0.001 else (Vector3.BACK if me.is_hero() else Vector3.FORWARD)
		var r := Battle3D.ARENA
		var edge := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.z - r.position.y, r.end.y - p.z))
		var w := clampf(1.0 - edge / WALL_MARGIN, 0.0, 1.0)
		var c := r.get_center()
		var to_center := (Vector3(c.x, 0.0, c.y) - p).normalized()
		var d := away + to_center * w * 1.6
		if d.dot(Vector3(threat.x, 0.0, threat.z) - p) > 0.0:
			var side := Vector3(-away.z, 0.0, away.x)
			d = side if side.dot(to_center) >= 0.0 else -side
		return d.normalized()

	func flee(threat: Vector3) -> void:
		me.move_dir = flee_dir(threat)

	func engage(target: Unit3D) -> void:
		if target == null:
			hold()
			return
		if me.is_ranged():
			keep_range(target, me.attack_range * 0.8)
		elif not me.in_reach(target):
			go_to(target.flat_pos())
		else:
			hold()
		me.try_attack(target)

	func keep_range(target: Unit3D, ideal: float, band := 40.0 * PX) -> void:
		var d := dist(target)
		if d > minf(ideal + band, me.attack_range * 0.95):
			go_to(target.flat_pos())
		elif d < ideal - band:
			flee(target.flat_pos())
		else:
			hold()


## Heroes share the FOCAR override.
class HeroAI extends AI:
	func think(delta: float) -> void:
		if battle.focus_active():
			focus(battle.focus_target, delta)
		else:
			ai(delta)

	func focus(target: Unit3D, _delta: float) -> void:
		engage(target)

	func ai(_delta: float) -> void:
		pass


## Brenna "Muralha": anchor on the strongest enemy; step between a hit ally and its attacker.
class Muralha extends HeroAI:
	const GUARD_RADIUS := 260.0 * PX

	func ai(delta: float) -> void:
		var best: Array = []
		var latest := -INF
		for a in allies():
			if a == me or dist(a) > GUARD_RADIUS or not a.under_attack():
				continue
			if a.last_hit_time > latest:
				latest = a.last_hit_time
				best = [a, a.last_attacker]
		if not best.is_empty():
			var ally: Unit3D = best[0]
			var attacker: Unit3D = best[1]
			var to_ally := (ally.flat_pos() - attacker.flat_pos()).normalized()
			var gap := minf(me.reach_to(attacker) - 4.0 * PX, attacker.dist_to(ally) * 0.5)
			go_to(attacker.flat_pos() + to_ally * gap, 6.0 * PX)
			battle.track("brenna_guard_s", delta)
			me.try_attack(attacker)
			return
		engage(pick_min(enemies(), func(u: Unit3D) -> float: return -u.hp))


## Yara "Paciência": ideal distance, most wounded in range, kite when too close.
class Paciencia extends HeroAI:
	const IDEAL := 240.0 * PX
	const TOO_CLOSE := 140.0 * PX

	func ai(delta: float) -> void:
		var foes := enemies()
		if foes.is_empty():
			hold()
			return
		var threat := nearest(foes)
		var in_range: Array[Unit3D] = foes.filter(func(u: Unit3D) -> bool: return me.in_reach(u))
		var target: Unit3D = threat if in_range.is_empty() else \
				pick_min(in_range, func(u: Unit3D) -> float: return u.hp_ratio() + u.hp * 0.0001)
		if dist(threat) < TOO_CLOSE:
			flee(threat.flat_pos())
			battle.track("yara_kite_s", delta)
		else:
			keep_range(target, IDEAL)
		me.try_attack(target)


## Orin "Triagem": heal lowest HP% whenever anyone is wounded; keep away; attack only if no one
## needs healing. Under FOCAR: keep healing allies below 30%, otherwise join the focus.
class Triagem extends HeroAI:
	const DANGER := 200.0 * PX

	func ai(_delta: float) -> void:
		var wounded: Array[Unit3D] = allies().filter(func(u: Unit3D) -> bool: return u.is_wounded())
		if not wounded.is_empty():
			_heal(pick_min(wounded, func(u: Unit3D) -> float: return u.hp_ratio()))
		else:
			_attack(nearest(enemies()))

	func focus(target: Unit3D, _delta: float) -> void:
		var critical: Array[Unit3D] = allies().filter(
				func(u: Unit3D) -> bool: return u.hp_ratio() < Defs.FOCUS_HEAL_THRESHOLD)
		if not critical.is_empty():
			_heal(pick_min(critical, func(u: Unit3D) -> float: return u.hp_ratio()))
		else:
			_attack(target)

	func _heal(ally: Unit3D) -> void:
		if not _step_away():
			if ally != me and dist(ally) > me.attack_range * 0.8:
				go_to(ally.flat_pos())
			else:
				hold()
		me.try_heal(ally)

	func _attack(target: Unit3D) -> void:
		if target == null:
			hold()
			return
		if not _step_away():
			keep_range(target, me.attack_range * 0.85)
		me.try_attack(target)

	func _step_away() -> bool:
		var threat := nearest(enemies())
		if threat != null and dist(threat) < DANGER:
			flee(threat.flat_pos())
			return true
		return false


## Kess "Oportunista": isolated targets, least HP, fall back after each kill.
class Oportunista extends HeroAI:
	const ISOLATION := 160.0 * PX
	const RETREAT_TIME := 1.4
	const RETARGET_EVERY := 0.5

	var _retreat := 0.0
	var _target: Unit3D
	var _retarget := 0.0

	func on_kill(_victim: Unit3D) -> void:
		_retreat = RETREAT_TIME
		_target = null

	func ai(delta: float) -> void:
		if _retreat > 0.0:
			_retreat -= delta
			var threat := nearest(enemies())
			if threat == null:
				hold()
				return
			var party := battle.hero_centroid()
			var to_party: Vector3 = (party - me.flat_pos()).normalized() if me.flat_pos().distance_to(party) > 40.0 * PX \
					else Vector3.ZERO
			me.move_dir = (flee_dir(threat.flat_pos()) + to_party * 0.6).normalized()
			battle.track("kess_retreat_s", delta)
			return
		_retarget -= delta
		if _target == null or _target.dead or _retarget <= 0.0:
			_retarget = RETARGET_EVERY
			var foes := enemies()
			var isolated: Array[Unit3D] = []
			for u in foes:
				var others: Array[Unit3D] = foes.filter(func(o: Unit3D) -> bool: return o != u)
				var n := nearest(others, u.flat_pos())
				if n == null or n.dist_to(u) > ISOLATION:
					isolated.append(u)
			_target = pick_min(isolated if not isolated.is_empty() else foes, func(u: Unit3D) -> float: return u.hp)
		engage(_target)


class Rastejante extends AI:
	func think(_delta: float) -> void:
		engage(nearest(enemies()))


class Fundeiro extends AI:
	const IDEAL := 200.0 * PX

	func think(_delta: float) -> void:
		var target := nearest(enemies())
		if target == null:
			hold()
			return
		keep_range(target, IDEAL, 50.0 * PX)
		me.try_attack(target)


class Bruto extends AI:
	var _target: Unit3D
	var _retarget := 0.0

	func think(delta: float) -> void:
		_retarget -= delta
		if _target == null or _target.dead or _retarget <= 0.0:
			_retarget = 1.0
			_target = pick_min(enemies(), func(u: Unit3D) -> float: return -u.hp)
		engage(_target)
