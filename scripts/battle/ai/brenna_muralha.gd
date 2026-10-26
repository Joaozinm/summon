class_name BrennaMuralha
extends HeroBrain
## "Muralha" (tank): advance to the strongest enemy and anchor there. If a nearby ally is
## being hit, step onto the line between attacker and ally (right in the attacker's face,
## which also blocks shots). Never retreats — this brain has no flee path.

const GUARD_RADIUS := 260.0


func ai(delta: float) -> void:
	var threat := _ally_under_attack()
	if not threat.is_empty():
		var ally: Unit = threat[0]
		var attacker: Unit = threat[1]
		var to_ally := (ally.position - attacker.position).normalized()
		var gap := minf(me.reach_to(attacker) - 4.0, attacker.position.distance_to(ally.position) * 0.5)
		go_to(attacker.position + to_ally * gap, 6.0)
		battle.track("brenna_guard_s", delta)
		me.try_attack(attacker)
		return
	var strongest := pick_min(enemies(), func(u: Unit) -> float: return -u.hp)
	engage(strongest)


## [ally, attacker] for the most recently hit ally within GUARD_RADIUS, or [].
func _ally_under_attack() -> Array:
	var best: Array = []
	var latest := -INF
	for a in allies():
		if a == me or dist(a) > GUARD_RADIUS or not a.under_attack():
			continue
		if a.last_hit_time > latest:
			latest = a.last_hit_time
			best = [a, a.last_attacker]
	return best
