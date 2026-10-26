class_name KessOportunista
extends HeroBrain
## "Oportunista" (assassin): hunt isolated enemies, burst the one with the least HP, and
## after each kill fall back toward the party to reposition (hit-and-run).

const ISOLATION := 160.0
const RETREAT_TIME := 1.4
const RETARGET_EVERY := 0.5

var _retreat := 0.0
var _target: Unit
var _retarget := 0.0


func on_kill(_victim: Unit) -> void:
	_retreat = RETREAT_TIME
	battle.track("kess_kills")
	_target = null


func ai(delta: float) -> void:
	if _retreat > 0.0:
		_retreat -= delta
		_fall_back()
		battle.track("kess_retreat_s", delta)
		return
	_retarget -= delta
	if _target == null or _target.dead or _retarget <= 0.0:
		_retarget = RETARGET_EVERY
		_target = _choose()
	engage(_target)


func _choose() -> Unit:
	var foes := enemies()
	var isolated: Array[Unit] = []
	for u in foes:
		var others: Array[Unit] = foes.filter(func(o: Unit) -> bool: return o != u)
		var n := nearest(others, u.position)
		if n == null or n.position.distance_to(u.position) > ISOLATION:
			isolated.append(u)
	var pool := isolated if not isolated.is_empty() else foes
	return pick_min(pool, func(u: Unit) -> float: return u.hp)


func _fall_back() -> void:
	var threat := nearest(enemies())
	if threat == null:
		hold()
		return
	var away := flee_dir(threat.position)
	var party := battle.hero_centroid()
	var to_party := (party - me.position).normalized() if me.position.distance_to(party) > 40.0 \
			else Vector2.ZERO
	me.move_dir = (away + to_party * 0.6).normalized()
